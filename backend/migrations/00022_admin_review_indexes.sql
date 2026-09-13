-- +goose Up
-- Stage 8 admin/review query indexes. Every other index the spec suggests
-- (users email/phone, products category_id/is_active, orders status/
-- created_at, payouts status/seller_id+requested_at) already exists from
-- earlier stages — only the genuinely missing ones are added here.

-- Admin user list filters by role and/or is_active together.
CREATE INDEX idx_users_role_is_active ON users(role, is_active);

-- Admin seller list filters by is_active and/or is_verified together.
CREATE INDEX idx_sellers_is_active_is_verified ON sellers(is_active, is_verified);

-- Both the public reviews endpoint (product_id + is_visible, sorted by
-- created_at) and the admin reviews list rely on this composite — the
-- existing idx_reviews_product_id alone doesn't cover the is_visible
-- filter or the sort.
CREATE INDEX idx_reviews_product_visible_created ON reviews(product_id, is_visible, created_at);

-- Admin payments list filters/sorts by status and date together; only a
-- single-column status index existed before.
CREATE INDEX idx_payments_status_created_at ON payments(status, created_at);

-- +goose Down
DROP INDEX IF EXISTS idx_payments_status_created_at;
DROP INDEX IF EXISTS idx_reviews_product_visible_created;
DROP INDEX IF EXISTS idx_sellers_is_active_is_verified;
DROP INDEX IF EXISTS idx_users_role_is_active;
