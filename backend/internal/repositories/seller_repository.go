package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type SellerRepository struct {
	pool *pgxpool.Pool
}

func NewSellerRepository(pool *pgxpool.Pool) *SellerRepository {
	return &SellerRepository{pool: pool}
}

// sellerOfferCountsCTE aggregates, per seller, how many valid offers (and
// how many distinct products) they currently have — reused by both the
// sellers list and the seller detail query.
const sellerOfferCountsCTE = `
	seller_offer_counts AS (
		SELECT seller_id, COUNT(*) AS offer_count, COUNT(DISTINCT product_id) AS product_count
		FROM valid_offers
		GROUP BY seller_id
	)
`

// ListActive returns every active seller. Never exposes the underlying
// user's email/phone/password or any balance/commission data (Stage 3 §11,
// §37) — those columns are not even selected here.
func (r *SellerRepository) ListActive(ctx context.Context) ([]models.SellerCard, error) {
	query := "WITH " + validOffersCTE + ", " + sellerOfferCountsCTE + `
		SELECT s.id, s.name, s.slug, s.description, s.rating::float8, s.review_count, s.is_verified,
			COALESCE(soc.offer_count, 0)
		FROM sellers s
		LEFT JOIN seller_offer_counts soc ON soc.seller_id = s.id
		WHERE s.is_active = TRUE
		ORDER BY s.rating DESC, s.id ASC
	`

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query sellers: %w", err)
	}
	defer rows.Close()

	sellers := []models.SellerCard{}
	for rows.Next() {
		var s models.SellerCard
		if err := rows.Scan(&s.ID, &s.Name, &s.Slug, &s.Description, &s.Rating, &s.ReviewCount, &s.IsVerified, &s.ActiveOfferCount); err != nil {
			return nil, fmt.Errorf("scan seller: %w", err)
		}
		sellers = append(sellers, s)
	}
	return sellers, rows.Err()
}

// GetByID returns a single active seller's public profile, or models.ErrNotFound.
func (r *SellerRepository) GetByID(ctx context.Context, id int64) (*models.SellerDetail, error) {
	query := "WITH " + validOffersCTE + ", " + sellerOfferCountsCTE + `
		SELECT s.id, s.name, s.slug, s.description, s.rating::float8, s.review_count, s.is_verified, s.is_active,
			COALESCE(soc.product_count, 0), COALESCE(soc.offer_count, 0)
		FROM sellers s
		LEFT JOIN seller_offer_counts soc ON soc.seller_id = s.id
		WHERE s.id = $1 AND s.is_active = TRUE
	`

	var s models.SellerDetail
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&s.ID, &s.Name, &s.Slug, &s.Description, &s.Rating, &s.ReviewCount, &s.IsVerified, &s.IsActive,
		&s.ProductCount, &s.ActiveOfferCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan seller %d: %w", id, err)
	}
	return &s, nil
}

// Exists reports whether an active seller with this id exists.
func (r *SellerRepository) Exists(ctx context.Context, id int64) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM sellers WHERE id = $1 AND is_active = TRUE)`, id).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check seller exists %d: %w", id, err)
	}
	return exists, nil
}

// ListProducts returns the products this seller currently has a valid offer
// for, priced at THIS seller's own offer — never the marketplace-wide
// cheapest offer, which may belong to a different seller (Stage 3 §13).
// If a seller somehow has more than one valid offer for the same product,
// their own cheapest offer for it is used (seller_ranked, rn = 1) so the
// result is still one row per product.
func (r *SellerRepository) ListProducts(ctx context.Context, sellerID int64, limit, offset int) ([]models.SellerProductItem, int, error) {
	cte := "WITH " + validOffersCTE + `,
		seller_ranked AS (
			SELECT vo.*, ROW_NUMBER() OVER (PARTITION BY vo.product_id ORDER BY vo.price ASC, vo.offer_id ASC) AS rn
			FROM valid_offers vo
			WHERE vo.seller_id = $1
		)
	`

	var total int
	countQuery := cte + `SELECT COUNT(*) FROM seller_ranked WHERE rn = 1`
	if err := r.pool.QueryRow(ctx, countQuery, sellerID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count seller products %d: %w", sellerID, err)
	}
	if total == 0 {
		return []models.SellerProductItem{}, 0, nil
	}

	listQuery := cte + fmt.Sprintf(`
		SELECT
			p.id, p.slug, p.name_ru, p.name_kk, p.name_en, p.brand, p.rating::float8, p.review_count,
			(SELECT pi.url FROM product_images pi WHERE pi.product_id = p.id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1) AS primary_image,
			sr.offer_id, sr.sku, sr.price::text, sr.old_price::text, %s, sr.delivery_days, sr.available_quantity
		FROM seller_ranked sr
		JOIN products p ON p.id = sr.product_id
		WHERE sr.rn = 1
		ORDER BY p.id ASC
		LIMIT $2 OFFSET $3
	`, discountExpr("sr.old_price", "sr.price")+" AS discount_percent")

	rows, err := r.pool.Query(ctx, listQuery, sellerID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("query seller products %d: %w", sellerID, err)
	}
	defer rows.Close()

	items := []models.SellerProductItem{}
	for rows.Next() {
		var (
			item     models.SellerProductItem
			price    string
			oldPrice *string
		)
		err := rows.Scan(
			&item.ProductID, &item.Slug, &item.Name.RU, &item.Name.KK, &item.Name.EN, &item.Brand,
			&item.Rating, &item.ReviewCount,
			&item.PrimaryImage,
			&item.OfferID, &item.SKU, &price, &oldPrice, &item.DiscountPercent,
			&item.DeliveryDays, &item.AvailableQuantity,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scan seller product: %w", err)
		}
		item.Price = models.Money(price)
		if oldPrice != nil {
			m := models.Money(*oldPrice)
			item.OldPrice = &m
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("iterate seller products: %w", err)
	}

	return items, total, nil
}
