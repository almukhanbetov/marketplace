package services

import (
	"context"
	"regexp"
	"strings"
	"time"
	"unicode"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// AuthService owns every authentication rule: password strength,
// registration uniqueness, login credential/account-status checks, token
// issuance, refresh rotation, and session revocation (Stage 9 §2/§3).
type AuthService struct {
	authRepo *repositories.AuthRepository
	// meRepo supplies GetDetail for /auth/me — the exact same
	// aggregate (orders/favorites/addresses counts, linked seller id) the
	// admin user-detail endpoint already computes (Stage 8), reused rather
	// than duplicated.
	meRepo          *repositories.AdminUserRepository
	jwtAccessSecret string
	accessTTL       time.Duration
	refreshTTL      time.Duration
}

func NewAuthService(authRepo *repositories.AuthRepository, meRepo *repositories.AdminUserRepository, jwtAccessSecret string, accessTTL, refreshTTL time.Duration) *AuthService {
	return &AuthService{authRepo: authRepo, meRepo: meRepo, jwtAccessSecret: jwtAccessSecret, accessTTL: accessTTL, refreshTTL: refreshTTL}
}

var (
	emailPattern = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)
	phonePattern = regexp.MustCompile(`^\+?[0-9]{7,15}$`)
)

func validatePasswordStrength(pw string) error {
	if len(pw) < 8 {
		return models.NewValidationError("WEAK_PASSWORD", "Password must be at least 8 characters")
	}
	var hasLetter, hasDigit bool
	for _, r := range pw {
		switch {
		case unicode.IsLetter(r):
			hasLetter = true
		case unicode.IsDigit(r):
			hasDigit = true
		}
	}
	if !hasLetter || !hasDigit {
		return models.NewValidationError("WEAK_PASSWORD", "Password must contain at least one letter and one digit")
	}
	return nil
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func toPublicUser(u *models.AuthUserRecord) *models.User {
	return &models.User{
		ID: u.ID, Email: u.Email, Phone: u.Phone, FullName: u.FullName,
		Role: u.Role, IsActive: u.IsActive, CreatedAt: u.CreatedAt, UpdatedAt: u.UpdatedAt,
	}
}

// Register creates a new customer account — role is never a parameter
// here, so no request body can make this anything but "customer" (Stage 9
// §8/§28/§55).
func (s *AuthService) Register(ctx context.Context, in models.RegisterInput) (*models.User, error) {
	email := strings.TrimSpace(in.Email)
	phone := strings.TrimSpace(in.Phone)
	fullName := strings.TrimSpace(in.FullName)

	if email == "" && phone == "" {
		return nil, models.NewValidationError("VALIDATION_ERROR", "email or phone is required")
	}
	if email != "" && !emailPattern.MatchString(email) {
		return nil, models.NewValidationError("VALIDATION_ERROR", "email must be a valid address")
	}
	if phone != "" && !phonePattern.MatchString(phone) {
		return nil, models.NewValidationError("VALIDATION_ERROR", "phone must be a valid phone number")
	}
	if fullName == "" {
		return nil, models.NewValidationError("VALIDATION_ERROR", "full_name is required")
	}
	if err := validatePasswordStrength(in.Password); err != nil {
		return nil, err
	}

	hash, err := auth.HashPassword(in.Password)
	if err != nil {
		return nil, err
	}

	userID, err := s.authRepo.CreateUser(ctx, nilIfEmpty(email), nilIfEmpty(phone), fullName, hash)
	if err != nil {
		if constraint, ok := repositories.ConstraintViolated(err); ok {
			switch constraint {
			case "users_email_key":
				return nil, models.NewConflictError("EMAIL_ALREADY_EXISTS", "An account with this email already exists")
			case "users_phone_key":
				return nil, models.NewConflictError("PHONE_ALREADY_EXISTS", "An account with this phone already exists")
			}
		}
		return nil, err
	}

	rec, err := s.authRepo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	return toPublicUser(rec), nil
}

// Login validates credentials and, on success, issues a fresh access
// token and a new refresh session. Stage 9 §11: wrong password and
// unknown account both fail with the same INVALID_CREDENTIALS — only
// after credentials are proven correct do we ever reveal ACCOUNT_DISABLED.
func (s *AuthService) Login(ctx context.Context, identifier, password string, userAgent, ip *string) (*models.User, *models.AuthTokens, error) {
	identifier = strings.TrimSpace(identifier)
	if identifier == "" || password == "" {
		return nil, nil, models.NewValidationError("VALIDATION_ERROR", "email/phone and password are required")
	}

	rec, err := s.authRepo.GetUserByEmailOrPhone(ctx, identifier)
	if err != nil {
		if err == models.ErrNotFound {
			return nil, nil, models.NewValidationError("INVALID_CREDENTIALS", "Invalid email/phone or password")
		}
		return nil, nil, err
	}

	if err := auth.ComparePassword(rec.PasswordHash, password); err != nil {
		return nil, nil, models.NewValidationError("INVALID_CREDENTIALS", "Invalid email/phone or password")
	}

	if !rec.IsActive {
		return nil, nil, models.NewValidationError("ACCOUNT_DISABLED", "This account has been disabled")
	}

	tokens, err := s.issueTokens(ctx, rec.ID, rec.Role, userAgent, ip)
	if err != nil {
		return nil, nil, err
	}

	_ = s.authRepo.UpdateLastLogin(ctx, rec.ID)
	rec.IsActive = true // already checked above; keep the record fresh for the response
	return toPublicUser(rec), tokens, nil
}

func (s *AuthService) issueTokens(ctx context.Context, userID int64, role string, userAgent, ip *string) (*models.AuthTokens, error) {
	access, accessExpires, err := auth.IssueAccessToken(s.jwtAccessSecret, userID, role, s.accessTTL)
	if err != nil {
		return nil, err
	}
	rawRefresh, err := auth.GenerateRefreshToken()
	if err != nil {
		return nil, err
	}
	refreshExpires := time.Now().Add(s.refreshTTL)
	if _, err := s.authRepo.CreateSession(ctx, userID, auth.HashRefreshToken(rawRefresh), refreshExpires, userAgent, ip); err != nil {
		return nil, err
	}
	return &models.AuthTokens{AccessToken: access, AccessTokenExpires: accessExpires, RefreshToken: rawRefresh, RefreshExpires: refreshExpires}, nil
}

// errSessionInvalid is the single internal signal for every refresh
// failure mode (not found, expired, revoked/reused, inactive user) — the
// handler always maps it to SESSION_EXPIRED (Stage 9 §14/§15/§57): a
// uniform response gives an attacker probing stolen/guessed tokens no
// information about which specific check failed.
var errSessionInvalid = models.NewValidationError("SESSION_EXPIRED", "Your session has expired. Please log in again.")

// Refresh validates the presented raw refresh token, rotates it (Stage 9
// §14), and detects reuse of an already-rotated/revoked token by revoking
// the entire session for that user (Stage 9 §15).
func (s *AuthService) Refresh(ctx context.Context, rawRefreshToken string, userAgent, ip *string) (*models.AuthTokens, error) {
	if rawRefreshToken == "" {
		return nil, errSessionInvalid
	}
	hash := auth.HashRefreshToken(rawRefreshToken)

	session, err := s.authRepo.GetSessionByHash(ctx, hash)
	if err != nil {
		if err == models.ErrNotFound {
			return nil, errSessionInvalid
		}
		return nil, err
	}

	if session.RevokedAt != nil {
		// This exact token was already rotated away (or explicitly logged
		// out) once before — presenting it again means it leaked. Treat
		// the whole session as compromised (Stage 9 §15).
		_ = s.authRepo.RevokeAllSessionsForUser(ctx, session.UserID)
		return nil, errSessionInvalid
	}
	if session.ExpiresAt.Before(time.Now()) {
		return nil, errSessionInvalid
	}

	rec, err := s.authRepo.GetUserByID(ctx, session.UserID)
	if err != nil || !rec.IsActive {
		return nil, errSessionInvalid
	}

	access, accessExpires, err := auth.IssueAccessToken(s.jwtAccessSecret, rec.ID, rec.Role, s.accessTTL)
	if err != nil {
		return nil, err
	}
	rawNewRefresh, err := auth.GenerateRefreshToken()
	if err != nil {
		return nil, err
	}
	newExpires := time.Now().Add(s.refreshTTL)

	_ = s.authRepo.TouchSession(ctx, session.ID)
	if _, err := s.authRepo.RotateSession(ctx, session.ID, rec.ID, auth.HashRefreshToken(rawNewRefresh), newExpires, userAgent, ip); err != nil {
		return nil, err
	}

	return &models.AuthTokens{AccessToken: access, AccessTokenExpires: accessExpires, RefreshToken: rawNewRefresh, RefreshExpires: newExpires}, nil
}

// Logout revokes the single session behind rawRefreshToken. Missing or
// already-invalid tokens are treated as "already logged out" — not an
// error — so a client can always safely call this.
func (s *AuthService) Logout(ctx context.Context, rawRefreshToken string) error {
	if rawRefreshToken == "" {
		return nil
	}
	session, err := s.authRepo.GetSessionByHash(ctx, auth.HashRefreshToken(rawRefreshToken))
	if err != nil {
		if err == models.ErrNotFound {
			return nil
		}
		return err
	}
	return s.authRepo.RevokeSession(ctx, session.ID)
}

// LogoutAll revokes every session belonging to userID (Stage 9 §17).
func (s *AuthService) LogoutAll(ctx context.Context, userID int64) error {
	return s.authRepo.RevokeAllSessionsForUser(ctx, userID)
}

// Me returns the current user's safe profile + aggregates for GET
// /auth/me (Stage 9 §13).
func (s *AuthService) Me(ctx context.Context, userID int64) (*models.UserDetail, error) {
	return s.meRepo.GetDetail(ctx, userID)
}
