-- +goose Up
-- payouts.seller_id is RESTRICT — same financial-history reasoning as
-- orders/commissions. No banking integration at this stage.
CREATE TABLE payouts (
    id            BIGSERIAL PRIMARY KEY,
    seller_id     BIGINT NOT NULL REFERENCES sellers(id) ON DELETE RESTRICT,
    amount        NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    status        VARCHAR(20) NOT NULL DEFAULT 'pending',
    requested_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at  TIMESTAMPTZ,
    CONSTRAINT payouts_status_check CHECK (status IN ('pending', 'processing', 'paid', 'rejected'))
);

CREATE INDEX idx_payouts_seller_id ON payouts(seller_id);
CREATE INDEX idx_payouts_status ON payouts(status);

-- +goose Down
DROP TABLE IF EXISTS payouts;
