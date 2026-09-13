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

// SellerOfferRepository covers both seller_offers and inventory — Stage 7
// keeps them in one repository deliberately (rather than a separate
// SellerInventoryRepository per the suggested name list) because every
// seller_offers row has exactly one 1:1 inventory row and every query here
// touches both; splitting them would just mean every method takes the same
// two tables anyway (Stage 7 §27 explicitly allows logical consolidation).
type SellerOfferRepository struct {
	pool *pgxpool.Pool
}

func NewSellerOfferRepository(pool *pgxpool.Pool) *SellerOfferRepository {
	return &SellerOfferRepository{pool: pool}
}

const sellerOfferSelect = `
	so.id, so.product_id, p.name_ru, p.name_kk, p.name_en, p.brand,
	(SELECT pi.url FROM product_images pi WHERE pi.product_id = p.id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1),
	so.sku, so.price::text, so.old_price::text, so.delivery_days, so.is_active,
	COALESCE(inv.available_quantity, 0), COALESCE(inv.reserved_quantity, 0),
	so.created_at, so.updated_at
`

const sellerOfferFromJoins = `
	FROM seller_offers so
	JOIN products p ON p.id = so.product_id
	LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
`

func scanSellerOffer(row rowScanner) (models.SellerOfferItem, error) {
	var (
		item     models.SellerOfferItem
		price    string
		oldPrice *string
	)
	err := row.Scan(
		&item.ID, &item.ProductID, &item.ProductName.RU, &item.ProductName.KK, &item.ProductName.EN, &item.Brand,
		&item.PrimaryImage,
		&item.SKU, &price, &oldPrice, &item.DeliveryDays, &item.IsActive,
		&item.AvailableQuantity, &item.ReservedQuantity,
		&item.CreatedAt, &item.UpdatedAt,
	)
	if err != nil {
		return item, err
	}
	item.Price = models.Money(price)
	if oldPrice != nil {
		m := models.Money(*oldPrice)
		item.OldPrice = &m
	}
	item.IsLowStock = item.AvailableQuantity <= models.LowStockThreshold
	return item, nil
}

// List returns a seller's own offers — never filtered to "currently
// purchasable" the way the public catalog is; a seller must see their own
// inactive/out-of-stock offers to manage them (Stage 7 §6).
func (r *SellerOfferRepository) List(ctx context.Context, sellerID int64, q models.SellerOfferQuery) ([]models.SellerOfferItem, int, error) {
	conditions := []string{"so.seller_id = $1"}
	args := []any{sellerID}
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Search != "" {
		p := next("%" + q.Search + "%")
		conditions = append(conditions, fmt.Sprintf("(p.name_ru ILIKE %s OR p.name_kk ILIKE %s OR p.name_en ILIKE %s OR so.sku ILIKE %s)", p, p, p, p))
	}
	if q.Status == "active" {
		conditions = append(conditions, "so.is_active = TRUE")
	} else if q.Status == "inactive" {
		conditions = append(conditions, "so.is_active = FALSE")
	}
	if q.LowStock {
		conditions = append(conditions, fmt.Sprintf("COALESCE(inv.available_quantity, 0) <= %d", models.LowStockThreshold))
	}

	orderBy := "so.created_at DESC, so.id DESC"
	switch q.Sort {
	case "price_asc":
		orderBy = "so.price ASC, so.id ASC"
	case "price_desc":
		orderBy = "so.price DESC, so.id ASC"
	case "stock_asc":
		orderBy = "COALESCE(inv.available_quantity, 0) ASC, so.id ASC"
	}

	where := strings.Join(conditions, " AND ")

	var total int
	countQuery := fmt.Sprintf("SELECT COUNT(*) %s WHERE %s", sellerOfferFromJoins, where)
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count seller offers: %w", err)
	}
	if total == 0 {
		return []models.SellerOfferItem{}, 0, nil
	}

	limitArg := next(q.Limit)
	offsetArg := next(q.Offset)
	listQuery := fmt.Sprintf("SELECT %s %s WHERE %s ORDER BY %s LIMIT %s OFFSET %s", sellerOfferSelect, sellerOfferFromJoins, where, orderBy, limitArg, offsetArg)

	rows, err := r.pool.Query(ctx, listQuery, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list seller offers: %w", err)
	}
	defer rows.Close()

	items := []models.SellerOfferItem{}
	for rows.Next() {
		item, err := scanSellerOffer(rows)
		if err != nil {
			return nil, 0, fmt.Errorf("scan seller offer: %w", err)
		}
		items = append(items, item)
	}
	return items, total, rows.Err()
}

// Create inserts a new seller_offers row for an existing product plus its
// 1:1 inventory row, in one transaction (Stage 7 §7).
func (r *SellerOfferRepository) Create(ctx context.Context, sellerID int64, in models.CreateOfferInput) (int64, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin create-offer transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var offerID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO seller_offers (seller_id, product_id, sku, price, old_price, delivery_days, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, TRUE)
		RETURNING id
	`, sellerID, in.ProductID, in.SKU, in.Price, nullIfEmpty(in.OldPrice), in.DeliveryDays).Scan(&offerID)
	if err != nil {
		return 0, err // caller checks IsUniqueViolation(err) for a duplicate SKU
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO inventory (seller_offer_id, available_quantity, reserved_quantity)
		VALUES ($1, $2, 0)
	`, offerID, in.Stock); err != nil {
		return 0, fmt.Errorf("insert inventory for new offer: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit create-offer transaction: %w", err)
	}
	return offerID, nil
}

// Update overwrites sku/price/old_price/delivery_days, scoped to the
// requesting seller — an offer id belonging to another seller is
// indistinguishable from a nonexistent one (Stage 7 §8/§29).
func (r *SellerOfferRepository) Update(ctx context.Context, sellerID, offerID int64, in models.UpdateOfferInput) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE seller_offers
		SET sku = $1, price = $2, old_price = $3, delivery_days = $4, updated_at = NOW()
		WHERE id = $5 AND seller_id = $6
	`, in.SKU, in.Price, nullIfEmpty(in.OldPrice), in.DeliveryDays, offerID, sellerID)
	if err != nil {
		return err // caller checks IsUniqueViolation(err) for a duplicate SKU
	}
	if tag.RowsAffected() == 0 {
		return models.NewNotFoundError("OFFER_NOT_FOUND", "Offer not found")
	}
	return nil
}

// UpdateStatus flips is_active, scoped to the requesting seller. Never
// deletes the row — order history may reference it (Stage 7 §9).
func (r *SellerOfferRepository) UpdateStatus(ctx context.Context, sellerID, offerID int64, isActive bool) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE seller_offers SET is_active = $1, updated_at = NOW() WHERE id = $2 AND seller_id = $3
	`, isActive, offerID, sellerID)
	if err != nil {
		return fmt.Errorf("update offer %d status: %w", offerID, err)
	}
	if tag.RowsAffected() == 0 {
		return models.NewNotFoundError("OFFER_NOT_FOUND", "Offer not found")
	}
	return nil
}

// GetOwnerSellerID returns the seller_id an offer belongs to, or
// models.ErrNotFound. Used by the service layer's cross-seller sanity
// checks that need the owner without mutating anything.
func (r *SellerOfferRepository) GetOwnerSellerID(ctx context.Context, offerID int64) (int64, error) {
	var sellerID int64
	err := r.pool.QueryRow(ctx, `SELECT seller_id FROM seller_offers WHERE id = $1`, offerID).Scan(&sellerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, models.ErrNotFound
		}
		return 0, fmt.Errorf("look up offer %d owner: %w", offerID, err)
	}
	return sellerID, nil
}

// --- Inventory ---

// ListInventory returns every offer's stock state for a seller.
func (r *SellerOfferRepository) ListInventory(ctx context.Context, sellerID int64) ([]models.SellerInventoryItem, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT so.id, so.product_id, p.name_ru, p.name_kk, p.name_en, so.sku,
			COALESCE(inv.available_quantity, 0), COALESCE(inv.reserved_quantity, 0), COALESCE(inv.updated_at, so.updated_at)
		FROM seller_offers so
		JOIN products p ON p.id = so.product_id
		LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
		WHERE so.seller_id = $1
		ORDER BY so.id ASC
	`, sellerID)
	if err != nil {
		return nil, fmt.Errorf("list inventory for seller %d: %w", sellerID, err)
	}
	defer rows.Close()

	items := []models.SellerInventoryItem{}
	for rows.Next() {
		var it models.SellerInventoryItem
		if err := rows.Scan(&it.OfferID, &it.ProductID, &it.ProductName.RU, &it.ProductName.KK, &it.ProductName.EN, &it.SKU,
			&it.AvailableQuantity, &it.ReservedQuantity, &it.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan inventory item: %w", err)
		}
		it.IsLowStock = it.AvailableQuantity <= models.LowStockThreshold
		items = append(items, it)
	}
	return items, rows.Err()
}

// UpdateInventory absolutely sets available_quantity for one of this
// seller's offers (Stage 7 §11) — scoped by joining through seller_offers
// so a cross-seller offer id can never be touched (§29), since the
// inventory table itself has no seller_id column.
func (r *SellerOfferRepository) UpdateInventory(ctx context.Context, sellerID, offerID int64, availableQuantity int) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE inventory inv
		SET available_quantity = $1, updated_at = NOW()
		FROM seller_offers so
		WHERE inv.seller_offer_id = so.id AND so.id = $2 AND so.seller_id = $3
	`, availableQuantity, offerID, sellerID)
	if err != nil {
		return fmt.Errorf("update inventory for offer %d: %w", offerID, err)
	}
	if tag.RowsAffected() == 0 {
		return models.NewNotFoundError("OFFER_NOT_FOUND", "Offer not found")
	}
	return nil
}
