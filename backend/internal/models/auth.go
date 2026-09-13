package models

import "time"

// AuthUserRecord is the internal, repository-layer view of a users row —
// the ONLY type in this codebase that ever carries PasswordHash. It is
// never serialized to JSON directly and never leaves the
// repository/service layer; every response type derived from it (User,
// UserDetail, AuthMeResponse) is built field-by-field, so there is no
// struct-tag mistake that could ever leak a hash (Stage 9 §13/§34/§54).
type AuthUserRecord struct {
	ID              int64
	Email           *string
	Phone           *string
	FullName        string
	PasswordHash    string
	Role            string
	IsActive        bool
	EmailVerifiedAt *time.Time
	LastLoginAt     *time.Time
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// RegisterInput is the validated POST /auth/register body. Role is
// deliberately absent — registration always creates a "customer" account;
// nothing in this type lets a caller request "admin" or "seller" (Stage 9
// §8/§55).
type RegisterInput struct {
	Email    string
	Phone    string
	FullName string
	Password string
}

// AuthTokens is what a successful login/refresh hands back to the
// service's caller (the handler) — the raw refresh token exists only
// transiently here, long enough to set the HttpOnly cookie; it is never
// logged and never returned in a JSON body (Stage 9 §3/§34).
type AuthTokens struct {
	AccessToken        string
	AccessTokenExpires time.Time
	RefreshToken       string
	RefreshExpires     time.Time
}

// AuthSession is one row of auth_sessions, as read back by the
// repository — RefreshTokenHash, never the raw token.
type AuthSession struct {
	ID               int64
	UserID           int64
	RefreshTokenHash string
	ExpiresAt        time.Time
	CreatedAt        time.Time
	LastUsedAt       time.Time
	RevokedAt        *time.Time
	UserAgent        *string
	IPAddress        *string
}
