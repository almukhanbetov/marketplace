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

type ProductRepository struct {
	pool *pgxpool.Pool
}

func NewProductRepository(pool *pgxpool.Pool) *ProductRepository {
	return &ProductRepository{pool: pool}
}

// productSortColumns whitelists every accepted sort value to a fixed ORDER
// BY fragment — a client-supplied sort string is looked up here, never
// interpolated into SQL directly (Stage 3 §20/§25).
var productSortColumns = map[models.SortOption]string{
	models.SortPriceAsc:     "best.price ASC, p.id ASC",
	models.SortPriceDesc:    "best.price DESC, p.id ASC",
	models.SortRatingDesc:   "p.rating DESC, p.id ASC",
	models.SortNewest:       "p.created_at DESC, p.id DESC",
	models.SortDiscountDesc: "discount_percent DESC, p.id ASC",
}

const defaultProductSort = "p.id ASC"

// buildProductFilterConditions turns a validated ProductFilter into WHERE
// conditions (ANDed with "p.is_active = TRUE" by the caller) and their
// positional args, starting at $paramOffset+1. It never builds a condition
// from a raw, unvalidated string — everything here already passed through
// ProductService's validation.
func buildProductFilterConditions(f models.ProductFilter, paramOffset int) ([]string, []any) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", paramOffset+len(args))
	}

	if f.Search != "" {
		p := next("%" + f.Search + "%")
		conditions = append(conditions, fmt.Sprintf(
			"(p.name_ru ILIKE %s OR p.name_kk ILIKE %s OR p.name_en ILIKE %s OR p.brand ILIKE %s)", p, p, p, p,
		))
	}
	if f.CategorySlug != "" {
		conditions = append(conditions, "c.slug = "+next(f.CategorySlug))
	}
	if f.CategoryID != nil {
		conditions = append(conditions, "c.id = "+next(*f.CategoryID))
	}
	if f.SellerSlug != "" {
		conditions = append(conditions, "EXISTS (SELECT 1 FROM valid_offers vof WHERE vof.product_id = p.id AND vof.seller_slug = "+next(f.SellerSlug)+")")
	}
	if f.SellerID != nil {
		conditions = append(conditions, "EXISTS (SELECT 1 FROM valid_offers vof WHERE vof.product_id = p.id AND vof.seller_id = "+next(*f.SellerID)+")")
	}
	if f.Brand != "" {
		conditions = append(conditions, "LOWER(p.brand) = LOWER("+next(f.Brand)+")")
	}
	if f.MinPrice != "" {
		conditions = append(conditions, "best.price >= "+next(f.MinPrice)+"::numeric")
	}
	if f.MaxPrice != "" {
		conditions = append(conditions, "best.price <= "+next(f.MaxPrice)+"::numeric")
	}
	if f.MinRating != "" {
		conditions = append(conditions, "p.rating >= "+next(f.MinRating)+"::numeric")
	}

	return conditions, args
}

// discountExprAlias is the same expression as discountExpr("best.old_price",
// "best.price"), given an alias so it can be reused in both SELECT and
// ORDER BY (Postgres allows referencing a SELECT-list alias in ORDER BY).
var discountExprAlias = discountExpr("best.old_price", "best.price") + " AS discount_percent"

var productCardSelect = `
	p.id, p.slug, p.brand, p.name_ru, p.name_kk, p.name_en, p.rating::float8, p.review_count,
	c.id, c.slug, c.name_ru, c.name_kk, c.name_en,
	best.price::text, best.old_price::text,
	` + discountExprAlias + `,
	best.offer_id, best.seller_name, best.seller_rating::float8,
	agg.seller_count, agg.min_delivery_days,
	(SELECT pi.url FROM product_images pi WHERE pi.product_id = p.id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1) AS primary_image
`

const productFromJoins = `
	FROM products p
	JOIN categories c ON c.id = p.category_id
	JOIN best_offers best ON best.product_id = p.id
	JOIN offer_agg agg ON agg.product_id = p.id
`

// List returns the filtered, sorted, paginated product cards plus the
// total count of matching products (ignoring limit/offset) for meta.total.
//
// Products with zero valid offers are excluded here by construction — the
// inner JOIN on best_offers/offer_agg only matches products that have at
// least one valid offer (Stage 3 §41: hidden from the purchasable catalog).
func (r *ProductRepository) List(ctx context.Context, f models.ProductFilter) ([]models.ProductCard, int, error) {
	conditions, args := buildProductFilterConditions(f, 0)
	where := "p.is_active = TRUE"
	if len(conditions) > 0 {
		where += " AND " + strings.Join(conditions, " AND ")
	}

	orderBy := productSortColumns[f.Sort]
	if orderBy == "" {
		orderBy = defaultProductSort
	}

	cte := "WITH " + validOffersCTE + ", " + bestOfferRankedCTE + ", " + offerAggCTE

	listQuery := fmt.Sprintf(`
		%s
		SELECT %s
		%s
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, cte, productCardSelect, productFromJoins, where, orderBy, len(args)+1, len(args)+2)

	countQuery := fmt.Sprintf(`
		%s
		SELECT COUNT(*)
		%s
		WHERE %s
	`, cte, productFromJoins, where)

	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count products: %w", err)
	}

	if total == 0 {
		return []models.ProductCard{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), f.Limit, f.Offset)
	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query products: %w", err)
	}
	defer rows.Close()

	items := []models.ProductCard{}
	for rows.Next() {
		pc, err := scanProductCard(rows)
		if err != nil {
			return nil, 0, fmt.Errorf("scan product card: %w", err)
		}
		items = append(items, pc)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("iterate products: %w", err)
	}

	return items, total, nil
}

func scanProductCard(row rowScanner) (models.ProductCard, error) {
	var (
		pc       models.ProductCard
		price    string
		oldPrice *string
	)
	err := row.Scan(
		&pc.ID, &pc.Slug, &pc.Brand, &pc.Name.RU, &pc.Name.KK, &pc.Name.EN, &pc.Rating, &pc.ReviewCount,
		&pc.Category.ID, &pc.Category.Slug, &pc.Category.Name.RU, &pc.Category.Name.KK, &pc.Category.Name.EN,
		&price, &oldPrice, &pc.DiscountPercent,
		&pc.BestOfferID, &pc.SellerName, &pc.SellerRating,
		&pc.SellerCount, &pc.MinDeliveryDays, &pc.PrimaryImage,
	)
	if err != nil {
		return pc, err
	}
	pc.Price = models.Money(price)
	if oldPrice != nil {
		m := models.Money(*oldPrice)
		pc.OldPrice = &m
	}
	return pc, nil
}

// Exists reports whether an active product with this id exists — used by
// the service layer to distinguish "product not found" (404) from "product
// found but currently has no purchasable offers" (empty offers list, 200).
func (r *ProductRepository) Exists(ctx context.Context, id int64) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM products WHERE id = $1 AND is_active = TRUE)`, id).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check product exists %d: %w", id, err)
	}
	return exists, nil
}

// GetByID returns the full product detail. Unlike List, this uses a LEFT
// JOIN to best_offers/offer_agg: a product that currently has zero valid
// offers is still a real, viewable catalog entry (e.g. temporarily out of
// stock everywhere) — it is only hidden from the *list* endpoint, not from
// its own detail page. In that case BestOffer is nil and SellerCount is 0.
func (r *ProductRepository) GetByID(ctx context.Context, id int64) (*models.ProductDetail, error) {
	cte := "WITH " + validOffersCTE + ", " + bestOfferRankedCTE + ", " + offerAggCTE
	query := fmt.Sprintf(`
		%s
		SELECT
			p.id, p.slug, p.brand, p.name_ru, p.name_kk, p.name_en,
			p.description_ru, p.description_kk, p.description_en,
			p.rating::float8, p.review_count,
			c.id, c.slug, c.name_ru, c.name_kk, c.name_en,
			COALESCE(agg.seller_count, 0),
			best.offer_id, best.seller_id, best.seller_name, best.seller_slug,
			best.seller_rating::float8, best.seller_verified, best.sku,
			best.price::text, best.old_price::text, %s,
			best.delivery_days, best.available_quantity
		FROM products p
		JOIN categories c ON c.id = p.category_id
		LEFT JOIN best_offers best ON best.product_id = p.id
		LEFT JOIN offer_agg agg ON agg.product_id = p.id
		WHERE p.id = $1 AND p.is_active = TRUE
	`, cte, discountExpr("best.old_price", "best.price"))

	row := r.pool.QueryRow(ctx, query, id)

	var (
		pd                              models.ProductDetail
		offerID, sellerID               *int64
		sellerName, sellerSlug, sku     *string
		sellerRating                    *float64
		sellerVerified                  *bool
		price, oldPrice                 *string
		discountPercent                 *int
		deliveryDays, availableQuantity *int
	)
	err := row.Scan(
		&pd.ID, &pd.Slug, &pd.Brand, &pd.Name.RU, &pd.Name.KK, &pd.Name.EN,
		&pd.Description.RU, &pd.Description.KK, &pd.Description.EN,
		&pd.Rating, &pd.ReviewCount,
		&pd.Category.ID, &pd.Category.Slug, &pd.Category.Name.RU, &pd.Category.Name.KK, &pd.Category.Name.EN,
		&pd.SellerCount,
		&offerID, &sellerID, &sellerName, &sellerSlug,
		&sellerRating, &sellerVerified, &sku,
		&price, &oldPrice, &discountPercent,
		&deliveryDays, &availableQuantity,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan product detail %d: %w", id, err)
	}

	if offerID != nil {
		offer := models.Offer{
			OfferID:           *offerID,
			SellerID:          *sellerID,
			SellerName:        *sellerName,
			SellerSlug:        *sellerSlug,
			SellerRating:      *sellerRating,
			SellerVerified:    *sellerVerified,
			SKU:               *sku,
			Price:             models.Money(*price),
			DiscountPercent:   *discountPercent,
			DeliveryDays:      *deliveryDays,
			AvailableQuantity: *availableQuantity,
		}
		if oldPrice != nil {
			m := models.Money(*oldPrice)
			offer.OldPrice = &m
		}
		pd.BestOffer = &offer
	}

	images, err := r.imagesForProduct(ctx, id)
	if err != nil {
		return nil, err
	}
	pd.Images = images

	return &pd, nil
}

// imagesForProduct returns image URLs in the deterministic order required
// by Stage 3 §39: primary first, then sort_order, then id.
func (r *ProductRepository) imagesForProduct(ctx context.Context, productID int64) ([]string, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT url FROM product_images
		WHERE product_id = $1
		ORDER BY is_primary DESC, sort_order ASC, id ASC
	`, productID)
	if err != nil {
		return nil, fmt.Errorf("query product images %d: %w", productID, err)
	}
	defer rows.Close()

	images := []string{}
	for rows.Next() {
		var url string
		if err := rows.Scan(&url); err != nil {
			return nil, fmt.Errorf("scan product image: %w", err)
		}
		images = append(images, url)
	}
	return images, rows.Err()
}

// ListOffers returns every valid, purchasable offer for one product,
// cheapest first (ties broken by higher seller rating) — Stage 3 §10.
func (r *ProductRepository) ListOffers(ctx context.Context, productID int64) ([]models.Offer, error) {
	query := "WITH " + validOffersCTE + fmt.Sprintf(`
		SELECT
			offer_id, seller_id, seller_name, seller_slug, seller_rating::float8, seller_verified,
			sku, price::text, old_price::text, %s, delivery_days, available_quantity
		FROM valid_offers
		WHERE product_id = $1
		ORDER BY price ASC, seller_rating DESC, offer_id ASC
	`, discountExpr("old_price", "price"))

	rows, err := r.pool.Query(ctx, query, productID)
	if err != nil {
		return nil, fmt.Errorf("query offers for product %d: %w", productID, err)
	}
	defer rows.Close()

	offers := []models.Offer{}
	for rows.Next() {
		o, err := scanOffer(rows)
		if err != nil {
			return nil, fmt.Errorf("scan offer: %w", err)
		}
		offers = append(offers, o)
	}
	return offers, rows.Err()
}

func scanOffer(row rowScanner) (models.Offer, error) {
	var (
		o        models.Offer
		price    string
		oldPrice *string
	)
	err := row.Scan(
		&o.OfferID, &o.SellerID, &o.SellerName, &o.SellerSlug, &o.SellerRating, &o.SellerVerified,
		&o.SKU, &price, &oldPrice, &o.DiscountPercent, &o.DeliveryDays, &o.AvailableQuantity,
	)
	if err != nil {
		return o, err
	}
	o.Price = models.Money(price)
	if oldPrice != nil {
		m := models.Money(*oldPrice)
		o.OldPrice = &m
	}
	return o, nil
}
