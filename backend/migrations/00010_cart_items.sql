-- +goose Up
-- A cart item points at a specific seller_offer, not a product — the buyer
-- has already picked which seller's offer they want, matching the
-- marketplace model (mirrors the frontend cart, which keys lines by offer).
CREATE TABLE cart_items (
    id               BIGSERIAL PRIMARY KEY,
    cart_id          BIGINT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    seller_offer_id  BIGINT NOT NULL REFERENCES seller_offers(id) ON DELETE RESTRICT,
    quantity         INTEGER NOT NULL CHECK (quantity > 0),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT cart_items_cart_offer_unique UNIQUE (cart_id, seller_offer_id)
);

-- cart_items(cart_id) is already served by the leading column of the
-- UNIQUE(cart_id, seller_offer_id) constraint above.
CREATE INDEX idx_cart_items_seller_offer_id ON cart_items(seller_offer_id);

-- +goose Down
DROP TABLE IF EXISTS cart_items;
