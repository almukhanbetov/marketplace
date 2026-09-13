-- +goose Up
CREATE TABLE inventory (
    id                  BIGSERIAL PRIMARY KEY,
    seller_offer_id     BIGINT NOT NULL UNIQUE REFERENCES seller_offers(id) ON DELETE CASCADE,
    available_quantity  INTEGER NOT NULL DEFAULT 0 CHECK (available_quantity >= 0),
    reserved_quantity   INTEGER NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- inventory(seller_offer_id) is already served by the UNIQUE constraint above.

-- +goose Down
DROP TABLE IF EXISTS inventory;
