-- +goose Up
-- 1:1 current-state extension of sellers (unlike orders/commissions, this
-- is not a historical log — CASCADE is appropriate here).
CREATE TABLE seller_balances (
    seller_id         BIGINT PRIMARY KEY REFERENCES sellers(id) ON DELETE CASCADE,
    pending_amount    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (pending_amount >= 0),
    available_amount  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (available_amount >= 0),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +goose Down
DROP TABLE IF EXISTS seller_balances;
