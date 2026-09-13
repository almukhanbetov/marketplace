-- +goose Up
CREATE TABLE addresses (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       VARCHAR(120),
    city        VARCHAR(120) NOT NULL,
    street      VARCHAR(200) NOT NULL,
    house       VARCHAR(20) NOT NULL,
    apartment   VARCHAR(20),
    postal_code VARCHAR(20),
    is_default  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_addresses_user_id ON addresses(user_id);

-- +goose Down
DROP TABLE IF EXISTS addresses;
