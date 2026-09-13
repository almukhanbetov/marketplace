package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// ErrInvalidAccessToken is returned by ParseAccessToken for any failure
// (bad signature, malformed token, expired) — deliberately one error for
// every case so callers can't be tempted to leak which check failed.
var ErrInvalidAccessToken = errors.New("invalid or expired access token")

// AccessClaims is the entire payload of an access JWT — deliberately
// minimal (Stage 9's design note in AuthService/RequireAuth): role is
// carried here only as a fast-path hint, never trusted alone. RequireAuth
// always reloads the user fresh from the database before authorizing
// anything, so a stale claim (e.g. a role changed or an account
// deactivated after this token was issued) can never grant access beyond
// the token's own short lifetime.
type AccessClaims struct {
	UserID int64  `json:"uid"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

// IssueAccessToken signs a short-lived access token for userID/role.
func IssueAccessToken(secret string, userID int64, role string, ttl time.Duration) (string, time.Time, error) {
	now := time.Now()
	expiresAt := now.Add(ttl)
	claims := AccessClaims{
		UserID: userID,
		Role:   role,
		RegisteredClaims: jwt.RegisteredClaims{
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(secret))
	if err != nil {
		return "", time.Time{}, err
	}
	return signed, expiresAt, nil
}

// ParseAccessToken validates signature and expiry and returns the claims,
// or ErrInvalidAccessToken for any failure.
func ParseAccessToken(secret, tokenString string) (*AccessClaims, error) {
	claims := &AccessClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidAccessToken
		}
		return []byte(secret), nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidAccessToken
	}
	if claims.UserID <= 0 || claims.Role == "" {
		return nil, ErrInvalidAccessToken
	}
	return claims, nil
}
