-- +goose Up
-- Stage 7: payout requests need the same double-submit protection Stage 6
-- gave orders (§24) — a seller double-clicking "request payout" must not
-- create two payouts or decrement available_amount twice.
ALTER TABLE payouts ADD COLUMN idempotency_key VARCHAR(100);

-- NULL is exempt (Postgres never treats two NULLs as equal), so a payout
-- created without one (shouldn't happen from the frontend, but not relied
-- upon) never spuriously collides with another.
CREATE UNIQUE INDEX idx_payouts_seller_idempotency_key ON payouts(seller_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- Payout history is always queried "this seller's payouts, newest first" —
-- idx_payouts_seller_id (Stage 2) already serves seller_id alone; this
-- composite index additionally covers the ORDER BY without a separate sort
-- step (Stage 7 §46).
CREATE INDEX idx_payouts_seller_requested_at ON payouts(seller_id, requested_at DESC);

-- +goose Down
DROP INDEX IF EXISTS idx_payouts_seller_requested_at;
DROP INDEX IF EXISTS idx_payouts_seller_idempotency_key;
ALTER TABLE payouts DROP COLUMN IF EXISTS idempotency_key;
