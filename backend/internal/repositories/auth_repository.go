package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type AuthRepository struct {
	pool *pgxpool.Pool
}

func NewAuthRepository(pool *pgxpool.Pool) *AuthRepository {
	return &AuthRepository{pool: pool}
}

// ConstraintViolated reports the constraint name of a unique-violation
// error, if any — lets the service distinguish EMAIL_ALREADY_EXISTS from
// PHONE_ALREADY_EXISTS on the same INSERT without a separate pre-check
// query (Stage 9 §9).
func ConstraintViolated(err error) (string, bool) {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return pgErr.ConstraintName, true
	}
	return "", false
}

const authUserColumns = `id, email, phone, full_name, password_hash, role, is_active, email_verified_at, last_login_at, created_at, updated_at`

func scanAuthUser(row rowScanner) (*models.AuthUserRecord, error) {
	var u models.AuthUserRecord
	err := row.Scan(&u.ID, &u.Email, &u.Phone, &u.FullName, &u.PasswordHash, &u.Role, &u.IsActive, &u.EmailVerifiedAt, &u.LastLoginAt, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// CreateUser inserts a new customer account. Role is always "customer" —
// there is no parameter to set anything else, by construction (Stage 9
// §8/§55: a crafted payload cannot register as admin/seller because the
// capability to choose a role simply doesn't exist on this path).
func (r *AuthRepository) CreateUser(ctx context.Context, email, phone *string, fullName, passwordHash string) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx, `
		INSERT INTO users (email, phone, full_name, password_hash, role, is_active)
		VALUES ($1, $2, $3, $4, 'customer', TRUE)
		RETURNING id
	`, email, phone, fullName, passwordHash).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

// GetUserByEmailOrPhone looks up an account by email OR phone — Stage 9
// §10 allows login by either identifier. Returns models.ErrNotFound if no
// account matches.
func (r *AuthRepository) GetUserByEmailOrPhone(ctx context.Context, identifier string) (*models.AuthUserRecord, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+authUserColumns+` FROM users WHERE email = $1 OR phone = $1`, identifier)
	u, err := scanAuthUser(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("get user by email/phone: %w", err)
	}
	return u, nil
}

// GetUserByID is the fresh, per-request lookup RequireAuth relies on —
// deliberately not cached, so a role change or deactivation takes effect
// on the very next request (Stage 9 §12/§18/§60).
func (r *AuthRepository) GetUserByID(ctx context.Context, id int64) (*models.AuthUserRecord, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+authUserColumns+` FROM users WHERE id = $1`, id)
	u, err := scanAuthUser(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("get user by id %d: %w", id, err)
	}
	return u, nil
}

func (r *AuthRepository) UpdateLastLogin(ctx context.Context, userID int64) error {
	_, err := r.pool.Exec(ctx, `UPDATE users SET last_login_at = NOW() WHERE id = $1`, userID)
	if err != nil {
		return fmt.Errorf("update last_login_at for user %d: %w", userID, err)
	}
	return nil
}

// ActiveSellerIDForUser returns the id of the sellers row linked to this
// user, only if that seller is currently active — nil otherwise (no
// linked seller at all, or the seller account is deactivated). Every
// seller-private route treats those two cases identically (Stage 9 §24).
func (r *AuthRepository) ActiveSellerIDForUser(ctx context.Context, userID int64) (*int64, error) {
	var sellerID int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM sellers WHERE user_id = $1 AND is_active = TRUE`, userID).Scan(&sellerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("find active seller for user %d: %w", userID, err)
	}
	return &sellerID, nil
}

// CreateSession inserts a new refresh-token session row.
func (r *AuthRepository) CreateSession(ctx context.Context, userID int64, refreshTokenHash string, expiresAt time.Time, userAgent, ipAddress *string) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx, `
		INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at, user_agent, ip_address)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, userID, refreshTokenHash, expiresAt, userAgent, ipAddress).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

// GetSessionByHash returns the session row for a hashed refresh token
// regardless of its revoked/expired state — the service layer decides
// what each state means (valid, expired, or a reused-token compromise
// signal), so this deliberately does not filter (Stage 9 §14/§15).
// models.ErrNotFound if no such hash was ever issued.
func (r *AuthRepository) GetSessionByHash(ctx context.Context, refreshTokenHash string) (*models.AuthSession, error) {
	var s models.AuthSession
	err := r.pool.QueryRow(ctx, `
		SELECT id, user_id, refresh_token_hash, expires_at, created_at, last_used_at, revoked_at, user_agent, ip_address
		FROM auth_sessions WHERE refresh_token_hash = $1
	`, refreshTokenHash).Scan(&s.ID, &s.UserID, &s.RefreshTokenHash, &s.ExpiresAt, &s.CreatedAt, &s.LastUsedAt, &s.RevokedAt, &s.UserAgent, &s.IPAddress)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("get session by hash: %w", err)
	}
	return &s, nil
}

// RevokeSession marks one session revoked — idempotent (revoking an
// already-revoked session is a no-op, not an error).
func (r *AuthRepository) RevokeSession(ctx context.Context, sessionID int64) error {
	_, err := r.pool.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE id = $1 AND revoked_at IS NULL`, sessionID)
	if err != nil {
		return fmt.Errorf("revoke session %d: %w", sessionID, err)
	}
	return nil
}

// RevokeAllSessionsForUser revokes every one of a user's still-valid
// sessions — used by logout-all (Stage 9 §17) and by reused-refresh-token
// compromise handling (Stage 9 §15).
func (r *AuthRepository) RevokeAllSessionsForUser(ctx context.Context, userID int64) error {
	_, err := r.pool.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`, userID)
	if err != nil {
		return fmt.Errorf("revoke all sessions for user %d: %w", userID, err)
	}
	return nil
}

// RotateSession atomically revokes oldSessionID and inserts a fresh
// session row for the same user — refresh token rotation (Stage 9 §14):
// the old token can never be presented successfully again after this
// commits, whether or not the new one is ever used.
func (r *AuthRepository) RotateSession(ctx context.Context, oldSessionID, userID int64, newRefreshTokenHash string, newExpiresAt time.Time, userAgent, ipAddress *string) (int64, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin rotate session transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, `UPDATE auth_sessions SET revoked_at = NOW() WHERE id = $1 AND revoked_at IS NULL`, oldSessionID); err != nil {
		return 0, fmt.Errorf("revoke old session %d: %w", oldSessionID, err)
	}

	var newID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO auth_sessions (user_id, refresh_token_hash, expires_at, user_agent, ip_address)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id
	`, userID, newRefreshTokenHash, newExpiresAt, userAgent, ipAddress).Scan(&newID)
	if err != nil {
		return 0, fmt.Errorf("insert rotated session: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit rotate session transaction: %w", err)
	}
	return newID, nil
}

// TouchSession updates last_used_at — called whenever a session's refresh
// token is successfully presented (before rotation), giving admins/future
// tooling a real "last active" signal per session.
func (r *AuthRepository) TouchSession(ctx context.Context, sessionID int64) error {
	_, err := r.pool.Exec(ctx, `UPDATE auth_sessions SET last_used_at = NOW() WHERE id = $1`, sessionID)
	if err != nil {
		return fmt.Errorf("touch session %d: %w", sessionID, err)
	}
	return nil
}

// CleanupExpiredSessions deletes sessions that expired more than a day
// ago (a short grace window, in case of clock skew or an in-flight
// request) — Stage 9 §64's "simple repository cleanup function", meant to
// be invoked periodically by an operator or a future scheduler; no
// scheduler infrastructure is added in Stage 9 itself. Returns how many
// rows were removed.
func (r *AuthRepository) CleanupExpiredSessions(ctx context.Context) (int64, error) {
	tag, err := r.pool.Exec(ctx, `DELETE FROM auth_sessions WHERE expires_at < NOW() - INTERVAL '1 day'`)
	if err != nil {
		return 0, fmt.Errorf("cleanup expired sessions: %w", err)
	}
	return tag.RowsAffected(), nil
}
