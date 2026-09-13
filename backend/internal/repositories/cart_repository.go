package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type CartRepository struct {
	pool *pgxpool.Pool
}

func NewCartRepository(pool *pgxpool.Pool) *CartRepository {
	return &CartRepository{pool: pool}
}

// cartItemSelect is shared by Get and the RETURNING-less refetch after a
// mutation — always priced from seller_offers' CURRENT row, never from
// anything the client sent (Stage 5 §12), and never filtered to only
// "currently valid" offers (unlike the catalog) so a since-deactivated item
// stays visible with is_available=false instead of silently vanishing
// (§13).
const cartItemSelect = `
	ci.id, ci.seller_offer_id, ci.quantity,
	p.id, p.brand, p.name_ru, p.name_kk, p.name_en,
	(SELECT pi.url FROM product_images pi WHERE pi.product_id = p.id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1),
	s.id, s.name, s.rating::float8,
	so.price::text, so.old_price::text, so.delivery_days,
	COALESCE(inv.available_quantity, 0),
	(so.is_active AND s.is_active AND p.is_active AND COALESCE(inv.available_quantity, 0) > 0)
`

const cartItemFromJoins = `
	FROM cart_items ci
	JOIN carts c ON c.id = ci.cart_id
	JOIN seller_offers so ON so.id = ci.seller_offer_id
	JOIN products p ON p.id = so.product_id
	JOIN sellers s ON s.id = so.seller_id
	LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
`

func scanCartItem(row rowScanner) (models.CartItem, error) {
	var (
		item        models.CartItem
		price       string
		oldPrice    *string
		productName models.LocalizedText
	)
	err := row.Scan(
		&item.ID, &item.SellerOfferID, &item.Quantity,
		&item.Product.ID, &item.Product.Brand, &productName.RU, &productName.KK, &productName.EN,
		&item.Product.PrimaryImage,
		&item.Seller.ID, &item.Seller.Name, &item.Seller.Rating,
		&price, &oldPrice, &item.DeliveryDays,
		&item.AvailableQuantity,
		&item.IsAvailable,
	)
	if err != nil {
		return item, err
	}
	item.Product.Name = productName
	item.Price = models.Money(price)
	if oldPrice != nil {
		m := models.Money(*oldPrice)
		item.OldPrice = &m
	}
	item.LineTotal = models.Money(multiplyMoney(price, item.Quantity))
	return item, nil
}

// Get returns the user's cart with all items, or an empty cart (ID nil) if
// they've never added anything — no row is created just by reading.
func (r *CartRepository) Get(ctx context.Context, userID int64) (*models.Cart, error) {
	cart := &models.Cart{UserID: userID, Items: []models.CartItem{}}

	var cartID int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM carts WHERE user_id = $1`, userID).Scan(&cartID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return cart, nil
		}
		return nil, fmt.Errorf("find cart for user %d: %w", userID, err)
	}
	cart.ID = &cartID

	query := fmt.Sprintf(`SELECT %s %s WHERE c.user_id = $1 ORDER BY ci.id ASC`, cartItemSelect, cartItemFromJoins)
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("query cart items for user %d: %w", userID, err)
	}
	defer rows.Close()

	for rows.Next() {
		item, err := scanCartItem(rows)
		if err != nil {
			return nil, fmt.Errorf("scan cart item: %w", err)
		}
		cart.Items = append(cart.Items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate cart items: %w", err)
	}

	cart.Summary = summarize(cart.Items)
	return cart, nil
}

func summarize(items []models.CartItem) models.CartSummary {
	subtotalCents := int64(0)
	itemCount := 0
	for _, i := range items {
		itemCount += i.Quantity
		subtotalCents += moneyToCents(string(i.LineTotal))
	}
	return models.CartSummary{ItemCount: itemCount, Subtotal: models.Money(centsToMoney(subtotalCents))}
}

// AddItem validates the offer/seller/product are active and the resulting
// quantity fits available inventory, then upserts the cart_items row —
// adding an offer already in the cart increments its quantity rather than
// creating a duplicate row (Stage 5 §10), guarded by
// `FOR UPDATE OF so` on the offer row so two concurrent adds of the same
// offer can't lost-update each other (§22). Returns a
// *models.NotFoundError / *models.ConflictError describing exactly why on
// failure.
func (r *CartRepository) AddItem(ctx context.Context, userID, sellerOfferID int64, quantity int) (*models.Cart, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin add-item transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var offerActive, sellerActive, productActive bool
	var available int
	err = tx.QueryRow(ctx, `
		SELECT so.is_active, s.is_active, p.is_active, COALESCE(inv.available_quantity, 0)
		FROM seller_offers so
		JOIN sellers s ON s.id = so.seller_id
		JOIN products p ON p.id = so.product_id
		LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
		WHERE so.id = $1
		FOR UPDATE OF so
	`, sellerOfferID).Scan(&offerActive, &sellerActive, &productActive, &available)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("SELLER_OFFER_NOT_FOUND", "Seller offer not found")
		}
		return nil, fmt.Errorf("lookup seller offer %d: %w", sellerOfferID, err)
	}
	if !offerActive || !sellerActive || !productActive {
		return nil, models.NewConflictError("OFFER_UNAVAILABLE", "This seller offer is no longer available")
	}

	var cartID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO carts (user_id) VALUES ($1)
		ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
		RETURNING id
	`, userID).Scan(&cartID)
	if err != nil {
		return nil, fmt.Errorf("upsert cart for user %d: %w", userID, err)
	}

	var existingQty int
	err = tx.QueryRow(ctx, `
		SELECT quantity FROM cart_items WHERE cart_id = $1 AND seller_offer_id = $2 FOR UPDATE
	`, cartID, sellerOfferID).Scan(&existingQty)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup existing cart item: %w", err)
	}
	newQty := existingQty + quantity

	if newQty > available {
		return nil, models.NewConflictError("INSUFFICIENT_STOCK", fmt.Sprintf("Only %d in stock", available))
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO cart_items (cart_id, seller_offer_id, quantity)
		VALUES ($1, $2, $3)
		ON CONFLICT (cart_id, seller_offer_id) DO UPDATE SET quantity = $3, updated_at = NOW()
	`, cartID, sellerOfferID, newQty)
	if err != nil {
		return nil, fmt.Errorf("upsert cart item: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit add-item transaction: %w", err)
	}

	return r.Get(ctx, userID)
}

// UpdateItemQuantity sets an item's quantity, scoped to the requesting
// user's own cart in the same WHERE clause — an item id belonging to
// another user's cart is indistinguishable from a nonexistent one
// (Stage 5 §16), never a separate ownership check callers could forget.
func (r *CartRepository) UpdateItemQuantity(ctx context.Context, userID, itemID int64, quantity int) (*models.Cart, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin update-quantity transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var available int
	err = tx.QueryRow(ctx, `
		SELECT COALESCE(inv.available_quantity, 0)
		FROM cart_items ci
		JOIN carts c ON c.id = ci.cart_id
		JOIN seller_offers so ON so.id = ci.seller_offer_id
		LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
		WHERE ci.id = $1 AND c.user_id = $2
		FOR UPDATE OF ci
	`, itemID, userID).Scan(&available)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("CART_ITEM_NOT_FOUND", "Cart item not found")
		}
		return nil, fmt.Errorf("lookup cart item %d: %w", itemID, err)
	}
	if quantity > available {
		return nil, models.NewConflictError("INSUFFICIENT_STOCK", fmt.Sprintf("Only %d in stock", available))
	}

	if _, err := tx.Exec(ctx, `UPDATE cart_items SET quantity = $1, updated_at = NOW() WHERE id = $2`, quantity, itemID); err != nil {
		return nil, fmt.Errorf("update cart item %d: %w", itemID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit update-quantity transaction: %w", err)
	}

	return r.Get(ctx, userID)
}

// RemoveItem deletes an item, scoped to the requesting user's own cart —
// same cross-user protection as UpdateItemQuantity.
func (r *CartRepository) RemoveItem(ctx context.Context, userID, itemID int64) (*models.Cart, error) {
	tag, err := r.pool.Exec(ctx, `
		DELETE FROM cart_items ci USING carts c
		WHERE ci.cart_id = c.id AND ci.id = $1 AND c.user_id = $2
	`, itemID, userID)
	if err != nil {
		return nil, fmt.Errorf("remove cart item %d: %w", itemID, err)
	}
	if tag.RowsAffected() == 0 {
		return nil, models.NewNotFoundError("CART_ITEM_NOT_FOUND", "Cart item not found")
	}
	return r.Get(ctx, userID)
}

// Clear removes every item from the user's cart. No error if the cart is
// already empty or doesn't exist yet.
func (r *CartRepository) Clear(ctx context.Context, userID int64) (*models.Cart, error) {
	_, err := r.pool.Exec(ctx, `
		DELETE FROM cart_items ci USING carts c
		WHERE ci.cart_id = c.id AND c.user_id = $1
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("clear cart for user %d: %w", userID, err)
	}
	return r.Get(ctx, userID)
}
