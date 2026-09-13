-- +goose Up
CREATE TABLE categories (
    id         BIGSERIAL PRIMARY KEY,
    parent_id  BIGINT REFERENCES categories(id) ON DELETE RESTRICT,
    name_ru    VARCHAR(160) NOT NULL,
    name_kk    VARCHAR(160) NOT NULL,
    name_en    VARCHAR(160) NOT NULL,
    slug       VARCHAR(160) NOT NULL UNIQUE,
    image_url  TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- categories(slug) is already served by the UNIQUE constraint above.
CREATE INDEX idx_categories_parent_id ON categories(parent_id);

-- +goose Down
DROP TABLE IF EXISTS categories;
