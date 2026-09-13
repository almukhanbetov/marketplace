-- +goose Up
-- At most one default address per user. Application code always clears the
-- old default in the same transaction before setting a new one (Stage 5
-- §19), but the partial unique index is the actual guarantee against races
-- or a future bug reintroducing two defaults.
CREATE UNIQUE INDEX idx_addresses_one_default_per_user ON addresses(user_id) WHERE is_default = TRUE;

-- +goose Down
DROP INDEX IF EXISTS idx_addresses_one_default_per_user;
