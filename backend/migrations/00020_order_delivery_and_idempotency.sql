-- +goose Up
-- Stage 6: order creation needs (a) a delivery destination that survives
-- the customer later editing/deleting their address book entry, and (b) a
-- way to recognize a duplicate checkout submission.
--
-- address_id is kept as a soft reference (SET NULL) purely for convenience
-- (e.g. a future "reorder to this address" feature) — it is NOT the
-- historical source of truth. The delivery_* columns are a snapshot taken
-- at order-creation time and never change afterwards, exactly like
-- order_items' own product/price snapshot (Stage 6 §26/§27).
ALTER TABLE orders
    ADD COLUMN address_id           BIGINT REFERENCES addresses(id) ON DELETE SET NULL,
    ADD COLUMN delivery_title       VARCHAR(120),
    ADD COLUMN delivery_city        VARCHAR(120),
    ADD COLUMN delivery_street      VARCHAR(200),
    ADD COLUMN delivery_house       VARCHAR(20),
    ADD COLUMN delivery_apartment   VARCHAR(20),
    ADD COLUMN delivery_postal_code VARCHAR(20),
    ADD COLUMN idempotency_key      VARCHAR(100);

-- A user can only ever have one order per idempotency key; NULL is exempt
-- (Postgres never treats two NULLs as equal), so orders created without
-- one (if that ever happens) never spuriously collide (Stage 6 §35/§36).
CREATE UNIQUE INDEX idx_orders_user_idempotency_key ON orders(user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- +goose Down
DROP INDEX IF EXISTS idx_orders_user_idempotency_key;
ALTER TABLE orders
    DROP COLUMN IF EXISTS address_id,
    DROP COLUMN IF EXISTS delivery_title,
    DROP COLUMN IF EXISTS delivery_city,
    DROP COLUMN IF EXISTS delivery_street,
    DROP COLUMN IF EXISTS delivery_house,
    DROP COLUMN IF EXISTS delivery_apartment,
    DROP COLUMN IF EXISTS delivery_postal_code,
    DROP COLUMN IF EXISTS idempotency_key;
