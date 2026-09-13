// Package auth is the single home for every authentication primitive:
// password hashing, JWT access tokens, refresh token generation/hashing,
// the authenticated-identity request context, and a minimal in-process
// rate limiter. Nothing outside this package touches bcrypt, jwt, or
// crypto/rand directly (Stage 9 §4/§19).
package auth

import "golang.org/x/crypto/bcrypt"

// bcryptCost balances hashing latency (~150-250ms on typical hardware)
// against brute-force resistance — 12 is the commonly recommended modern
// default (Stage 9 §4: "bcrypt with appropriate cost").
const bcryptCost = 12

// HashPassword returns the bcrypt hash of a plaintext password. Never
// returns the plaintext itself, and the resulting hash already embeds its
// own salt (bcrypt's standard $2a$ format) — no separate salt column
// needed.
func HashPassword(plain string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(plain), bcryptCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

// ComparePassword reports whether plain matches hash. Returns a non-nil
// error (never panics) on mismatch or a malformed hash — callers must
// treat any error as "authentication failed" and never branch on its
// specific text (Stage 9 §11: don't leak which check failed).
func ComparePassword(hash, plain string) error {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain))
}
