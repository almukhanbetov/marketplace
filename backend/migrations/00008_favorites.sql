-- +goose Up
CREATE TABLE favorites (
    user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id BIGINT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, product_id)
);

-- favorites(user_id) is already served by the leading column of the
-- composite primary key above.
CREATE INDEX idx_favorites_product_id ON favorites(product_id);

-- +goose Down
DROP TABLE IF EXISTS favorites;
