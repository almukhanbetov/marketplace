package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// AdminProductRepository manages global catalog identity (products +
// product_images) — deliberately separate from the public ProductRepository,
// which only ever sees is_active = TRUE rows with at least one valid offer.
// Admin needs to see and edit everything (Stage 8 §13).
type AdminProductRepository struct {
	pool *pgxpool.Pool
}

func NewAdminProductRepository(pool *pgxpool.Pool) *AdminProductRepository {
	return &AdminProductRepository{pool: pool}
}

var adminProductSortColumns = map[string]string{
	"":                "p.created_at DESC, p.id DESC",
	"created_at_asc":  "p.created_at ASC, p.id ASC",
	"created_at_desc": "p.created_at DESC, p.id DESC",
	"name_asc":        "p.name_ru ASC, p.id ASC",
}

func (r *AdminProductRepository) List(ctx context.Context, q models.AdminProductQuery) ([]models.AdminProductListItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Search != "" {
		p := next("%" + q.Search + "%")
		conditions = append(conditions, fmt.Sprintf("(p.name_ru ILIKE %s OR p.name_kk ILIKE %s OR p.name_en ILIKE %s OR p.brand ILIKE %s)", p, p, p, p))
	}
	if q.CategoryID != nil {
		conditions = append(conditions, "p.category_id = "+next(*q.CategoryID))
	}
	if q.Status == "active" {
		conditions = append(conditions, "p.is_active = TRUE")
	} else if q.Status == "inactive" {
		conditions = append(conditions, "p.is_active = FALSE")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	orderBy := adminProductSortColumns[q.Sort]
	if orderBy == "" {
		orderBy = adminProductSortColumns[""]
	}

	countQuery := "SELECT COUNT(*) FROM products p WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin products: %w", err)
	}
	if total == 0 {
		return []models.AdminProductListItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT
			p.id, p.slug, p.brand, p.name_ru, p.name_kk, p.name_en,
			c.id, c.slug, c.name_ru, c.name_kk, c.name_en,
			p.rating::float8, p.review_count,
			(SELECT pi.url FROM product_images pi WHERE pi.product_id = p.id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1),
			(SELECT COUNT(*) FROM seller_offers so WHERE so.product_id = p.id) AS offer_count,
			p.is_active, p.created_at
		FROM products p
		JOIN categories c ON c.id = p.category_id
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, where, orderBy, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin products: %w", err)
	}
	defer rows.Close()

	items := []models.AdminProductListItem{}
	for rows.Next() {
		var it models.AdminProductListItem
		if err := rows.Scan(
			&it.ID, &it.Slug, &it.Brand, &it.Name.RU, &it.Name.KK, &it.Name.EN,
			&it.Category.ID, &it.Category.Slug, &it.Category.Name.RU, &it.Category.Name.KK, &it.Category.Name.EN,
			&it.Rating, &it.ReviewCount, &it.PrimaryImage, &it.OfferCount, &it.IsActive, &it.CreatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan admin product: %w", err)
		}
		items = append(items, it)
	}
	return items, total, rows.Err()
}

func (r *AdminProductRepository) GetByID(ctx context.Context, id int64) (*models.AdminProductDetail, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT
			p.id, p.slug, p.brand, p.name_ru, p.name_kk, p.name_en,
			p.description_ru, p.description_kk, p.description_en,
			c.id, c.slug, c.name_ru, c.name_kk, c.name_en,
			p.rating::float8, p.review_count,
			(SELECT COUNT(*) FROM seller_offers so WHERE so.product_id = p.id) AS offer_count,
			p.is_active, p.created_at, p.updated_at
		FROM products p
		JOIN categories c ON c.id = p.category_id
		WHERE p.id = $1
	`, id)

	var d models.AdminProductDetail
	err := row.Scan(
		&d.ID, &d.Slug, &d.Brand, &d.Name.RU, &d.Name.KK, &d.Name.EN,
		&d.Description.RU, &d.Description.KK, &d.Description.EN,
		&d.Category.ID, &d.Category.Slug, &d.Category.Name.RU, &d.Category.Name.KK, &d.Category.Name.EN,
		&d.Rating, &d.ReviewCount, &d.OfferCount, &d.IsActive, &d.CreatedAt, &d.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin product detail %d: %w", id, err)
	}

	images, err := r.imagesForProduct(ctx, id)
	if err != nil {
		return nil, err
	}
	d.Images = images
	return &d, nil
}

func (r *AdminProductRepository) imagesForProduct(ctx context.Context, productID int64) ([]models.AdminProductImage, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, url, is_primary, sort_order FROM product_images
		WHERE product_id = $1
		ORDER BY is_primary DESC, sort_order ASC, id ASC
	`, productID)
	if err != nil {
		return nil, fmt.Errorf("query product images %d: %w", productID, err)
	}
	defer rows.Close()

	images := []models.AdminProductImage{}
	for rows.Next() {
		var img models.AdminProductImage
		if err := rows.Scan(&img.ID, &img.URL, &img.IsPrimary, &img.SortOrder); err != nil {
			return nil, fmt.Errorf("scan product image: %w", err)
		}
		images = append(images, img)
	}
	return images, rows.Err()
}

// normalizeImages ensures exactly one primary image where practical (Stage
// 8 §17): if the caller marked one, its choice wins; if none were marked,
// the first image in the slice becomes primary.
func normalizeImages(images []models.ProductImageInput) []models.ProductImageInput {
	if len(images) == 0 {
		return images
	}
	hasPrimary := false
	for _, img := range images {
		if img.IsPrimary {
			hasPrimary = true
			break
		}
	}
	if !hasPrimary {
		images[0].IsPrimary = true
	}
	return images
}

// Create inserts a product and its images in one transaction — if any
// image insert fails, the whole product is rolled back (Stage 8 §14/§70).
// Never creates a seller_offer.
func (r *AdminProductRepository) Create(ctx context.Context, in models.CreateProductInput) (int64, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin create product transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var productID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO products (
			category_id, brand, name_ru, name_kk, name_en,
			description_ru, description_kk, description_en, slug, is_active
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id
	`, in.CategoryID, in.Brand, in.NameRU, in.NameKK, in.NameEN,
		in.DescriptionRU, in.DescriptionKK, in.DescriptionEN, in.Slug, in.IsActive,
	).Scan(&productID)
	if err != nil {
		return 0, err
	}

	if err := insertProductImages(ctx, tx, productID, normalizeImages(in.Images)); err != nil {
		return 0, err
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit create product transaction: %w", err)
	}
	return productID, nil
}

func insertProductImages(ctx context.Context, tx pgx.Tx, productID int64, images []models.ProductImageInput) error {
	for _, img := range images {
		if _, err := tx.Exec(ctx, `
			INSERT INTO product_images (product_id, url, is_primary, sort_order)
			VALUES ($1, $2, $3, $4)
		`, productID, img.URL, img.IsPrimary, img.SortOrder); err != nil {
			return fmt.Errorf("insert product image: %w", err)
		}
	}
	return nil
}

// Update replaces the product's editable fields and, if Images is
// non-nil, replaces its image set entirely — both in one transaction
// (Stage 8 §15/§17). Never touches seller-specific price/inventory.
// Returns models.ErrNotFound if the product doesn't exist.
func (r *AdminProductRepository) Update(ctx context.Context, id int64, in models.UpdateProductInput) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin update product transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	tag, err := tx.Exec(ctx, `
		UPDATE products SET
			category_id = $1, brand = $2, name_ru = $3, name_kk = $4, name_en = $5,
			description_ru = $6, description_kk = $7, description_en = $8, slug = $9,
			is_active = $10, updated_at = NOW()
		WHERE id = $11
	`, in.CategoryID, in.Brand, in.NameRU, in.NameKK, in.NameEN,
		in.DescriptionRU, in.DescriptionKK, in.DescriptionEN, in.Slug, in.IsActive, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}

	if in.Images != nil {
		if _, err := tx.Exec(ctx, `DELETE FROM product_images WHERE product_id = $1`, id); err != nil {
			return fmt.Errorf("delete old product images: %w", err)
		}
		if err := insertProductImages(ctx, tx, id, normalizeImages(in.Images)); err != nil {
			return err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit update product transaction: %w", err)
	}
	return nil
}

// UpdateStatus flips is_active. An inactive product disappears from the
// public catalog because ProductRepository.List/GetByID/valid_offers all
// require p.is_active = TRUE (Stage 3, unchanged) — historical order_items
// keep their own product_name/sku snapshot regardless (Stage 8 §16).
func (r *AdminProductRepository) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	tag, err := r.pool.Exec(ctx, `UPDATE products SET is_active = $1, updated_at = NOW() WHERE id = $2`, isActive, id)
	if err != nil {
		return fmt.Errorf("update product status %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}
