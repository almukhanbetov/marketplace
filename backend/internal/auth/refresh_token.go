package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
)

// refreshTokenBytes is the raw entropy of a refresh token — 32 bytes
// (256 bits) is far beyond brute-force range, so the token can be hashed
// with a fast, unsalted SHA-256 for DB lookup (unlike a human password,
// there is no low-entropy keyspace an attacker could precompute against;
// bcrypt's deliberate slowness would only cost us on every request with
// no corresponding security benefit here).
const refreshTokenBytes = 32

// GenerateRefreshToken returns a new high-entropy, URL-safe random token.
// This is the only place the raw token ever exists outside the client's
// HttpOnly cookie — it is never logged and never stored as-is (Stage 9
// §6/§34).
func GenerateRefreshToken() (string, error) {
	buf := make([]byte, refreshTokenBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("generate refresh token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// HashRefreshToken returns the hex-encoded SHA-256 hash of a raw refresh
// token, for storage/lookup in auth_sessions.refresh_token_hash. Never
// reversible — the raw token can't be recovered from this hash.
func HashRefreshToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(sum[:])
}
