-- +goose Up
CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    email         VARCHAR(255) UNIQUE,
    phone         VARCHAR(32) UNIQUE,
    full_name     VARCHAR(255) NOT NULL,
    password_hash TEXT,
    role          VARCHAR(20) NOT NULL DEFAULT 'customer',
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_role_check CHECK (role IN ('customer', 'seller', 'admin')),
    CONSTRAINT users_email_or_phone_check CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

-- users(email) and users(phone) lookups are already served by the UNIQUE
-- constraints above; no separate indexes needed.

-- +goose Down
DROP TABLE IF EXISTS users;
