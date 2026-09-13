-- +goose Up
-- orders.user_id is RESTRICT, not CASCADE: an order is a financial/history
-- record and must not be silently destroyed by deleting the user who
-- placed it. Deactivate the user (is_active = false) instead.
CREATE TABLE orders (
    id                BIGSERIAL PRIMARY KEY,
    user_id           BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status            VARCHAR(20) NOT NULL DEFAULT 'new',
    subtotal          NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    discount_total    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (discount_total >= 0),
    delivery_total    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (delivery_total >= 0),
    commission_total  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (commission_total >= 0),
    total             NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    currency          VARCHAR(3) NOT NULL DEFAULT 'KZT',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT orders_status_check CHECK (
        status IN ('new', 'confirmed', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'returned')
    )
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- +goose Down
DROP TABLE IF EXISTS orders;
