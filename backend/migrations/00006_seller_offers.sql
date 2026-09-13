-- +goose Up
-- The core marketplace relationship: one product can have N seller_offers
-- from different sellers, each with its own price, SKU and delivery time.
-- No UNIQUE(seller_id, product_id) is added on purpose — a seller may list
-- the same product more than once as separate SKUs/variants in the future.
CREATE TABLE seller_offers (
    id             BIGSERIAL PRIMARY KEY,
    seller_id      BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    product_id     BIGINT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    sku            VARCHAR(64) NOT NULL,
    price          NUMERIC(14,2) NOT NULL CHECK (price >= 0),
    old_price      NUMERIC(14,2) CHECK (old_price IS NULL OR old_price >= 0),
    delivery_days  INTEGER NOT NULL DEFAULT 1 CHECK (delivery_days >= 0),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT seller_offers_seller_sku_unique UNIQUE (seller_id, sku)
);

-- seller_offers(seller_id) lookups are already served by the leading column
-- of the UNIQUE(seller_id, sku) constraint above.
CREATE INDEX idx_seller_offers_product_id ON seller_offers(product_id);
CREATE INDEX idx_seller_offers_price ON seller_offers(price);
CREATE INDEX idx_seller_offers_is_active ON seller_offers(is_active);

-- +goose Down
DROP TABLE IF EXISTS seller_offers;
