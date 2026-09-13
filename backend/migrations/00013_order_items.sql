-- +goose Up
-- Historical snapshot: product_name/sku/unit_price/commission are copied at
-- order time and never change afterwards, even if the seller later edits
-- or removes the underlying product/offer.
--
-- FK strategy for this table specifically:
--   seller_id        RESTRICT  — financial attribution must survive; a
--                                 seller with order history cannot be
--                                 hard-deleted (deactivate instead).
--   product_id        SET NULL — catalog can be cleaned up later; the
--                                 product_name snapshot already preserves
--                                 what the buyer saw, so losing the FK link
--                                 loses no historical information.
--   seller_offer_id    SET NULL — same reasoning as product_id, offers
--                                 churn more often than sellers.
--   order_id          CASCADE  — order_items are owned by their order; they
--                                 have no independent meaning without it.
CREATE TABLE order_items (
    id                  BIGSERIAL PRIMARY KEY,
    order_id            BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    seller_id           BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    product_id          BIGINT REFERENCES products(id) ON DELETE SET NULL,
    seller_offer_id     BIGINT REFERENCES seller_offers(id) ON DELETE SET NULL,
    product_name        VARCHAR(300) NOT NULL,
    sku                 VARCHAR(64) NOT NULL,
    quantity            INTEGER NOT NULL CHECK (quantity > 0),
    unit_price          NUMERIC(14,2) NOT NULL CHECK (unit_price >= 0),
    total_price         NUMERIC(14,2) NOT NULL CHECK (total_price >= 0),
    commission_rate     NUMERIC(5,4) NOT NULL DEFAULT 0 CHECK (commission_rate >= 0),
    commission_amount   NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (commission_amount >= 0),
    seller_amount       NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (seller_amount >= 0),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_seller_id ON order_items(seller_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- +goose Down
DROP TABLE IF EXISTS order_items;
