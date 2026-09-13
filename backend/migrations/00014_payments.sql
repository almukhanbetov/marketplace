-- +goose Up
-- Mock payment providers only — no real gateway integration at this stage.
CREATE TABLE payments (
    id                  BIGSERIAL PRIMARY KEY,
    order_id            BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    provider            VARCHAR(30) NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',
    amount              NUMERIC(14,2) NOT NULL CHECK (amount >= 0),
    currency            VARCHAR(3) NOT NULL DEFAULT 'KZT',
    external_reference  VARCHAR(200),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT payments_provider_check CHECK (
        provider IN ('card', 'kaspi_mock', 'apple_pay_mock', 'google_pay_mock')
    ),
    CONSTRAINT payments_status_check CHECK (
        status IN ('pending', 'paid', 'failed', 'cancelled', 'refunded')
    )
);

CREATE INDEX idx_payments_order_id ON payments(order_id);
CREATE INDEX idx_payments_status ON payments(status);

-- +goose Down
DROP TABLE IF EXISTS payments;
