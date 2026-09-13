-- +goose Up
-- commissions.seller_id is RESTRICT for the same reason as order_items:
-- financial history must not be destroyed by deleting the seller row.
CREATE TABLE commissions (
    id             BIGSERIAL PRIMARY KEY,
    order_item_id  BIGINT NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    seller_id      BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    rate           NUMERIC(5,4) NOT NULL CHECK (rate >= 0),
    amount         NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_commissions_order_item_id ON commissions(order_item_id);
CREATE INDEX idx_commissions_seller_id ON commissions(seller_id);

-- +goose Down
DROP TABLE IF EXISTS commissions;
