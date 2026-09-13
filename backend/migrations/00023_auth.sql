-- +goose Up
-- Stage 9: production-grade authentication. email_verified_at is added now
-- so a future stage can add real verification without another users
-- migration; Stage 9 itself never sets it (no email delivery yet, per
-- spec). last_login_at is updated on every successful login.
ALTER TABLE users ADD COLUMN email_verified_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN last_login_at TIMESTAMPTZ;

-- auth_sessions holds one row per issued refresh token — never the raw
-- token itself, only its SHA-256 hash (Stage 9 §6). A row represents one
-- browser/device session: rotated on every /auth/refresh (old row
-- revoked, new row inserted), revoked on logout, and all of a user's rows
-- revoked on logout-all or on detected refresh-token reuse.
CREATE TABLE auth_sessions (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash  TEXT NOT NULL,
    expires_at          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at          TIMESTAMPTZ,
    user_agent          TEXT,
    ip_address          TEXT
);

CREATE UNIQUE INDEX idx_auth_sessions_refresh_token_hash ON auth_sessions(refresh_token_hash);
CREATE INDEX idx_auth_sessions_user_id ON auth_sessions(user_id);
CREATE INDEX idx_auth_sessions_expires_at ON auth_sessions(expires_at);

-- +goose Down
DROP TABLE IF EXISTS auth_sessions;
ALTER TABLE users DROP COLUMN IF EXISTS last_login_at;
ALTER TABLE users DROP COLUMN IF EXISTS email_verified_at;
