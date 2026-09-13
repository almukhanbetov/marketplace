-- +goose Up
-- One active cart per user for now — no status column, just a UNIQUE
-- user_id. Abandoned/multiple-cart support can be added later without
-- breaking this shape.
CREATE TABLE carts (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- carts(user_id) is already served by the UNIQUE constraint above.

-- +goose Down
DROP TABLE IF EXISTS carts;
