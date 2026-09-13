-- +goose Up
CREATE TABLE reviews (
    id          BIGSERIAL PRIMARY KEY,
    product_id  BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    user_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    text        TEXT,
    is_visible  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT reviews_user_product_unique UNIQUE (user_id, product_id)
);

-- reviews(user_id) is already served by the leading column of the
-- UNIQUE(user_id, product_id) constraint above.
CREATE INDEX idx_reviews_product_id ON reviews(product_id);

-- +goose Down
DROP TABLE IF EXISTS reviews;
