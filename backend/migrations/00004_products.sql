-- +goose Up
-- Products are pure catalog identity: brand, names, description, category.
-- Deliberately no seller_id here — who sells a product, at what price and
-- with what stock, lives entirely in seller_offers (see 00006). A product
-- can be listed by zero, one, or many sellers.
CREATE TABLE products (
    id               BIGSERIAL PRIMARY KEY,
    category_id      BIGINT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    brand            VARCHAR(160),
    name_ru          VARCHAR(300) NOT NULL,
    name_kk          VARCHAR(300) NOT NULL,
    name_en          VARCHAR(300) NOT NULL,
    description_ru   TEXT,
    description_kk   TEXT,
    description_en   TEXT,
    slug             VARCHAR(320) NOT NULL UNIQUE,
    rating           NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating >= 0 AND rating <= 5),
    review_count     INTEGER NOT NULL DEFAULT 0 CHECK (review_count >= 0),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- products(slug) is already served by the UNIQUE constraint above.
CREATE INDEX idx_products_category_id ON products(category_id);
CREATE INDEX idx_products_brand ON products(brand);
CREATE INDEX idx_products_is_active ON products(is_active);

-- +goose Down
DROP TABLE IF EXISTS products;
