package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

const authTestJWTSecret = "services-test-jwt-secret-at-least-32-characters-long"

func newAuthTestService(pool *pgxpool.Pool) *services.AuthService {
	return services.NewAuthService(
		repositories.NewAuthRepository(pool),
		repositories.NewAdminUserRepository(pool),
		authTestJWTSecret, 15*time.Minute, 30*24*time.Hour,
	)
}

// uniqueTestEmail returns a fresh email every call — every auth test
// self-registers a brand-new account rather than reusing a seeded fixture,
// so this whole file can never collide with any other package's use of
// the seeded users/sellers (`go test ./...` runs each package concurrently
// against the same real dev database).
func uniqueTestEmail(name string) string {
	return fmt.Sprintf("%s-%d@example.com", name, time.Now().UnixNano())
}

func deleteTestUser(t *testing.T, pool *pgxpool.Pool, userID int64) {
	t.Helper()
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM auth_sessions WHERE user_id = $1`, userID)
	pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
}

func registerTestUser(t *testing.T, service *services.AuthService, email, password string) *models.User {
	t.Helper()
	user, err := service.Register(context.Background(), models.RegisterInput{
		Email: email, FullName: "Auth Test User", Password: password,
	})
	if err != nil {
		t.Fatalf("Register(%s) error = %v", email, err)
	}
	return user
}

// --- Register ---

func TestAuthService_Register_Success(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("register-success")

	user := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })

	if user.Role != "customer" {
		t.Errorf("Role = %q, want customer", user.Role)
	}
	if !user.IsActive {
		t.Error("newly registered user is not active")
	}
	if user.Email == nil || *user.Email != email {
		t.Errorf("Email = %v, want %s", user.Email, email)
	}
}

func TestAuthService_Register_DuplicateEmail_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("register-dup-email")

	user := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })

	_, err := service.Register(context.Background(), models.RegisterInput{Email: email, FullName: "Another User", Password: "Password456"})
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "EMAIL_ALREADY_EXISTS" {
		t.Errorf("Register(duplicate email) error = %v, want *models.ConflictError{EMAIL_ALREADY_EXISTS}", err)
	}
}

func TestAuthService_Register_DuplicatePhone_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	phone := fmt.Sprintf("+7701%07d", time.Now().UnixNano()%10000000)

	user, err := service.Register(context.Background(), models.RegisterInput{Phone: phone, FullName: "Phone User", Password: "Password123"})
	if err != nil {
		t.Fatalf("first Register() error = %v", err)
	}
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })

	_, err = service.Register(context.Background(), models.RegisterInput{Phone: phone, FullName: "Second User", Password: "Password456"})
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "PHONE_ALREADY_EXISTS" {
		t.Errorf("Register(duplicate phone) error = %v, want *models.ConflictError{PHONE_ALREADY_EXISTS}", err)
	}
}

func TestAuthService_Register_InvalidEmail_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	_, err := service.Register(context.Background(), models.RegisterInput{Email: "not-an-email", FullName: "X", Password: "Password123"})
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Register(invalid email) error = %v, want *models.ValidationError", err)
	}
}

func TestAuthService_Register_WeakPassword_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	cases := []string{"short1", "alllettersnodigits", "12345678"}
	for _, pw := range cases {
		_, err := service.Register(context.Background(), models.RegisterInput{Email: uniqueTestEmail("weak"), FullName: "X", Password: pw})
		ve, ok := err.(*models.ValidationError)
		if !ok || ve.Code != "WEAK_PASSWORD" {
			t.Errorf("Register(password=%q) error = %v, want *models.ValidationError{WEAK_PASSWORD}", pw, err)
		}
	}
}

// TestAuthService_Register_CannotSelfAssignRole covers Stage 9 §8/§28/§55:
// models.RegisterInput has no Role field at all — there is no way for a
// caller to request anything but "customer", by construction.
func TestAuthService_Register_CannotSelfAssignRole(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	user := registerTestUser(t, service, uniqueTestEmail("no-role-escalation"), "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })
	if user.Role != "customer" {
		t.Fatalf("Role = %q, want customer (models.RegisterInput has no role field to smuggle one through)", user.Role)
	}
}

// --- Login ---

func TestAuthService_Login_Success(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("login-success")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	ua, ip := "test-agent", "127.0.0.1"
	user, tokens, err := service.Login(context.Background(), email, "Password123", &ua, &ip)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}
	if user.ID != registered.ID {
		t.Errorf("logged-in user id = %d, want %d", user.ID, registered.ID)
	}
	if tokens.AccessToken == "" {
		t.Error("expected a non-empty access token")
	}
	if tokens.RefreshToken == "" {
		t.Error("expected a non-empty refresh token")
	}
	if tokens.RefreshToken == tokens.AccessToken {
		t.Error("refresh token must not equal the access token")
	}

	claims, err := auth.ParseAccessToken(authTestJWTSecret, tokens.AccessToken)
	if err != nil {
		t.Fatalf("issued access token does not parse: %v", err)
	}
	if claims.UserID != registered.ID || claims.Role != "customer" {
		t.Errorf("claims = %+v, want UserID=%d Role=customer", claims, registered.ID)
	}
}

func TestAuthService_Login_WrongPassword_InvalidCredentials(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("login-wrong-password")
	user := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })

	_, _, err := service.Login(context.Background(), email, "WrongPassword1", nil, nil)
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_CREDENTIALS" {
		t.Errorf("Login(wrong password) error = %v, want *models.ValidationError{INVALID_CREDENTIALS}", err)
	}
}

// TestAuthService_Login_UnknownAccount_SameErrorAsWrongPassword covers
// Stage 9 §11: an unknown account and a wrong password must be
// indistinguishable to the caller.
func TestAuthService_Login_UnknownAccount_SameErrorAsWrongPassword(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)

	_, _, err := service.Login(context.Background(), uniqueTestEmail("does-not-exist"), "WhateverPassword1", nil, nil)
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "INVALID_CREDENTIALS" {
		t.Errorf("Login(unknown account) error = %v, want *models.ValidationError{INVALID_CREDENTIALS}", err)
	}
}

func TestAuthService_Login_InactiveUser_AccountDisabled(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("login-inactive")
	user := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, user.ID) })

	pool.Exec(context.Background(), `UPDATE users SET is_active = FALSE WHERE id = $1`, user.ID)

	_, _, err := service.Login(context.Background(), email, "Password123", nil, nil)
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "ACCOUNT_DISABLED" {
		t.Errorf("Login(inactive user) error = %v, want *models.ValidationError{ACCOUNT_DISABLED}", err)
	}
}

// --- Refresh ---

func TestAuthService_Refresh_ValidToken_RotatesAndIssuesNewAccessToken(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("refresh-valid")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokens, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}

	newTokens, err := service.Refresh(context.Background(), tokens.RefreshToken, nil, nil)
	if err != nil {
		t.Fatalf("Refresh() error = %v", err)
	}
	if newTokens.RefreshToken == tokens.RefreshToken {
		t.Error("Refresh() did not rotate the refresh token")
	}
	if newTokens.AccessToken == "" {
		t.Error("Refresh() returned an empty access token")
	}
}

func TestAuthService_Refresh_RevokedTokenReuse_RevokesWholeSessionChain(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("refresh-reuse")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokens, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}
	oldRefresh := tokens.RefreshToken

	newTokens, err := service.Refresh(context.Background(), oldRefresh, nil, nil)
	if err != nil {
		t.Fatalf("first Refresh() error = %v", err)
	}

	// Reusing the now-rotated-away old token must fail...
	_, err = service.Refresh(context.Background(), oldRefresh, nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh(reused old token) error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}

	// ...and the legitimately-rotated NEW token must now ALSO be dead,
	// because reuse revoked the whole session chain (Stage 9 §15).
	_, err = service.Refresh(context.Background(), newTokens.RefreshToken, nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh(new token after reuse was detected) error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}
}

func TestAuthService_Refresh_ExpiredToken_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("refresh-expired")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokens, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}

	// Force the session to already be expired.
	pool.Exec(context.Background(), `UPDATE auth_sessions SET expires_at = NOW() - INTERVAL '1 hour' WHERE user_id = $1`, registered.ID)

	_, err = service.Refresh(context.Background(), tokens.RefreshToken, nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh(expired token) error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}
}

func TestAuthService_Refresh_InactiveUser_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("refresh-inactive")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokens, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}

	pool.Exec(context.Background(), `UPDATE users SET is_active = FALSE WHERE id = $1`, registered.ID)

	_, err = service.Refresh(context.Background(), tokens.RefreshToken, nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh(inactive user) error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}
}

func TestAuthService_Refresh_UnknownToken_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	_, err := service.Refresh(context.Background(), "not-a-real-refresh-token", nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh(unknown token) error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}
}

// --- Logout ---

func TestAuthService_Logout_MakesRefreshTokenUnusable(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("logout")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokens, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}

	if err := service.Logout(context.Background(), tokens.RefreshToken); err != nil {
		t.Fatalf("Logout() error = %v", err)
	}

	_, err = service.Refresh(context.Background(), tokens.RefreshToken, nil, nil)
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Refresh() after logout error = %v, want *models.ValidationError{SESSION_EXPIRED}", err)
	}
}

func TestAuthService_LogoutAll_RevokesEverySession(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAuthTestService(pool)
	email := uniqueTestEmail("logout-all")
	registered := registerTestUser(t, service, email, "Password123")
	t.Cleanup(func() { deleteTestUser(t, pool, registered.ID) })

	_, tokensA, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() A error = %v", err)
	}
	_, tokensB, err := service.Login(context.Background(), email, "Password123", nil, nil)
	if err != nil {
		t.Fatalf("Login() B error = %v", err)
	}

	if err := service.LogoutAll(context.Background(), registered.ID); err != nil {
		t.Fatalf("LogoutAll() error = %v", err)
	}

	if _, err := service.Refresh(context.Background(), tokensA.RefreshToken, nil, nil); err == nil {
		t.Error("session A still usable after LogoutAll()")
	}
	if _, err := service.Refresh(context.Background(), tokensB.RefreshToken, nil, nil); err == nil {
		t.Error("session B still usable after LogoutAll()")
	}
}
