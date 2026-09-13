package repositories

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// formatOrderNumber derives a human-facing order number from the id and
// creation year without any schema change (Stage 6 §28: "if this
// complicates Stage 6 unnecessarily, keep numeric ID" — this keeps the
// numeric id as the actual identity, just formats it for display,
// deterministically and collision-free since it's a pure function of the
// id itself, not a separately-generated/stored value).
func formatOrderNumber(id int64, createdAt time.Time) string {
	return fmt.Sprintf("MK-%d-%06d", createdAt.Year(), id)
}

type OrderRepository struct {
	pool *pgxpool.Pool
}

func NewOrderRepository(pool *pgxpool.Pool) *OrderRepository {
	return &OrderRepository{pool: pool}
}

// Begin starts the single transaction the entire order-creation workflow
// runs in. Every other write method below takes that same pgx.Tx
// explicitly — none of them opens its own transaction — so the *service*
// layer owns the transaction boundary and the exact sequence of steps
// (Stage 6 §5/§6), not a low-level repository function.
func (r *OrderRepository) Begin(ctx context.Context) (pgx.Tx, error) {
	return r.pool.Begin(ctx)
}

// CartLineForOrder is the fully revalidated state of one cart line, locked
// for the duration of the order transaction — never trusted from Stage 5's
// cart cache (Stage 6 §18).
type CartLineForOrder struct {
	CartItemID    int64
	SellerOfferID int64
	SellerID      int64
	SellerName    string
	SellerActive  bool
	ProductID     int64
	ProductNameRU string
	SKU           string
	Price         string // current seller_offers.price, decimal string
	OfferActive   bool
	ProductActive bool
	Quantity      int
}

// LoadCartLinesForUpdate loads every line in the user's cart and locks each
// referenced seller_offers row (FOR UPDATE), ordered deterministically by
// seller_offer_id so two transactions touching overlapping offers always
// acquire locks in the same order (Stage 6 §56 — deadlock avoidance). This
// intentionally does not reuse CartRepository.Get: that query reflects
// Stage 5's cached "is_available" for display, not a locked, transaction-
// fresh revalidation (Stage 6 §18).
func (r *OrderRepository) LoadCartLinesForUpdate(ctx context.Context, tx pgx.Tx, userID int64) ([]CartLineForOrder, error) {
	rows, err := tx.Query(ctx, `
		SELECT
			ci.id, ci.seller_offer_id, ci.quantity,
			so.seller_id, so.product_id, so.sku, so.price::text, so.is_active,
			s.name, s.is_active,
			p.name_ru, p.is_active
		FROM cart_items ci
		JOIN carts c ON c.id = ci.cart_id
		JOIN seller_offers so ON so.id = ci.seller_offer_id
		JOIN sellers s ON s.id = so.seller_id
		JOIN products p ON p.id = so.product_id
		WHERE c.user_id = $1
		ORDER BY so.id ASC
		FOR UPDATE OF so
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("load cart lines for order: %w", err)
	}
	defer rows.Close()

	var lines []CartLineForOrder
	for rows.Next() {
		var l CartLineForOrder
		if err := rows.Scan(
			&l.CartItemID, &l.SellerOfferID, &l.Quantity,
			&l.SellerID, &l.ProductID, &l.SKU, &l.Price, &l.OfferActive,
			&l.SellerName, &l.SellerActive,
			&l.ProductNameRU, &l.ProductActive,
		); err != nil {
			return nil, fmt.Errorf("scan cart line for order: %w", err)
		}
		lines = append(lines, l)
	}
	return lines, rows.Err()
}

// GetAddressSnapshot validates the address belongs to userID and returns
// its fields to copy into the order (Stage 6 §26/§27) — models.ErrNotFound
// if it doesn't exist or belongs to someone else, identical treatment to
// AddressRepository's own ownership check.
func (r *OrderRepository) GetAddressSnapshot(ctx context.Context, tx pgx.Tx, userID, addressID int64) (*models.DeliverySnapshot, error) {
	var snap models.DeliverySnapshot
	var ownerID int64
	err := tx.QueryRow(ctx, `
		SELECT user_id, title, city, street, house, apartment, postal_code
		FROM addresses
		WHERE id = $1
	`, addressID).Scan(&ownerID, &snap.Title, &snap.City, &snap.Street, &snap.House, &snap.Apartment, &snap.PostalCode)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
		}
		return nil, fmt.Errorf("load address %d: %w", addressID, err)
	}
	if ownerID != userID {
		return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
	}
	return &snap, nil
}

// DecrementInventory atomically decrements available_quantity with the
// availability check built into the WHERE clause — the preferred approach
// from Stage 6 §15: a single conditional UPDATE, not a separate SELECT
// followed by a blind UPDATE. Combined with the FOR UPDATE lock already
// held on the seller_offers row (which serializes concurrent checkouts of
// the same offer), this is safe against two concurrent orders both buying
// the last unit (Stage 6 §16) without needing a second explicit lock on
// the inventory row itself. Returns false (no error) if there wasn't
// enough stock, so the caller can produce a clean INSUFFICIENT_STOCK.
func (r *OrderRepository) DecrementInventory(ctx context.Context, tx pgx.Tx, sellerOfferID int64, quantity int) (bool, error) {
	tag, err := tx.Exec(ctx, `
		UPDATE inventory
		SET available_quantity = available_quantity - $1, updated_at = NOW()
		WHERE seller_offer_id = $2 AND available_quantity >= $1
	`, quantity, sellerOfferID)
	if err != nil {
		return false, fmt.Errorf("decrement inventory for offer %d: %w", sellerOfferID, err)
	}
	return tag.RowsAffected() > 0, nil
}

// FindOrderIDByIdempotencyKey is the fast-path idempotent-replay check —
// called once before opening the write transaction, so a plain repeat
// submission (the common case) never pays for a transaction at all (Stage
// 6 §35/§65). The UNIQUE(user_id, idempotency_key) index is the actual
// safety net against a race between two simultaneous first submissions —
// see CreateOrder's handling of a unique-violation on insert.
func (r *OrderRepository) FindOrderIDByIdempotencyKey(ctx context.Context, userID int64, key string) (*int64, error) {
	if key == "" {
		return nil, nil
	}
	var id int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM orders WHERE user_id = $1 AND idempotency_key = $2`, userID, key).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("find order by idempotency key: %w", err)
	}
	return &id, nil
}

// IsUniqueViolation reports whether err is a Postgres unique_violation
// (SQLSTATE 23505) — used by the service layer to detect a concurrent
// duplicate-idempotency-key insert that the pre-check couldn't see yet.
func IsUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}

// CreateOrder inserts the orders row. If idempotencyKey collides with one
// already committed by a concurrent request, returns isUniqueViolation(err)
// == true so the caller can roll back and fetch the winning order instead
// of erroring (Stage 6 §35/§36).
func (r *OrderRepository) CreateOrder(ctx context.Context, tx pgx.Tx, userID, addressID int64, delivery models.DeliverySnapshot, subtotal, deliveryTotal, commissionTotal, total string, idempotencyKey string) (int64, error) {
	var orderID int64
	err := tx.QueryRow(ctx, `
		INSERT INTO orders (
			user_id, status, subtotal, discount_total, delivery_total, commission_total, total, currency,
			address_id, delivery_title, delivery_city, delivery_street, delivery_house, delivery_apartment, delivery_postal_code,
			idempotency_key
		)
		VALUES ($1, $2, $3, 0, $4, $5, $6, 'KZT', $7, $8, $9, $10, $11, $12, $13, $14)
		RETURNING id
	`,
		userID, models.OrderStatusNew, subtotal, deliveryTotal, commissionTotal, total,
		addressID, delivery.Title, delivery.City, delivery.Street, delivery.House, delivery.Apartment, delivery.PostalCode,
		nullIfEmpty(idempotencyKey),
	).Scan(&orderID)
	if err != nil {
		return 0, err // caller checks isUniqueViolation(err) before wrapping
	}
	return orderID, nil
}

// OrderItemInsert is the fully computed, immutable snapshot for one line
// (Stage 6 §13).
type OrderItemInsert struct {
	SellerID         int64
	ProductID        int64
	SellerOfferID    int64
	ProductName      string
	SKU              string
	Quantity         int
	UnitPrice        string
	TotalPrice       string
	CommissionRate   string
	CommissionAmount string
	SellerAmount     string
}

func (r *OrderRepository) CreateOrderItem(ctx context.Context, tx pgx.Tx, orderID int64, in OrderItemInsert) (int64, error) {
	var id int64
	err := tx.QueryRow(ctx, `
		INSERT INTO order_items (
			order_id, seller_id, product_id, seller_offer_id,
			product_name, sku, quantity, unit_price, total_price,
			commission_rate, commission_amount, seller_amount
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id
	`, orderID, in.SellerID, in.ProductID, in.SellerOfferID, in.ProductName, in.SKU, in.Quantity, in.UnitPrice, in.TotalPrice, in.CommissionRate, in.CommissionAmount, in.SellerAmount).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("insert order item: %w", err)
	}
	return id, nil
}

func (r *OrderRepository) CreateCommission(ctx context.Context, tx pgx.Tx, orderItemID, sellerID int64, rate, amount string) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO commissions (order_item_id, seller_id, rate, amount)
		VALUES ($1, $2, $3, $4)
	`, orderItemID, sellerID, rate, amount)
	if err != nil {
		return fmt.Errorf("insert commission for order item %d: %w", orderItemID, err)
	}
	return nil
}

func (r *OrderRepository) CreatePayment(ctx context.Context, tx pgx.Tx, orderID int64, provider models.PaymentProvider, status, amount, externalReference string) error {
	_, err := tx.Exec(ctx, `
		INSERT INTO payments (order_id, provider, status, amount, currency, external_reference)
		VALUES ($1, $2, $3, $4, 'KZT', $5)
	`, orderID, provider, status, amount, externalReference)
	if err != nil {
		return fmt.Errorf("insert payment for order %d: %w", orderID, err)
	}
	return nil
}

func (r *OrderRepository) UpdateOrderStatus(ctx context.Context, tx pgx.Tx, orderID int64, status models.OrderStatus) error {
	_, err := tx.Exec(ctx, `UPDATE orders SET status = $1, updated_at = NOW() WHERE id = $2`, status, orderID)
	if err != nil {
		return fmt.Errorf("update order %d status: %w", orderID, err)
	}
	return nil
}

// AddSellerPendingBalance credits a seller's PENDING (not available)
// balance — Stage 6 §22: funds move to available_amount only once a later
// delivery/return lifecycle (not implemented yet) confirms the sale.
// seller_balances is seeded with one row per seller (Stage 2), so this is
// always an UPDATE, never an upsert.
func (r *OrderRepository) AddSellerPendingBalance(ctx context.Context, tx pgx.Tx, sellerID int64, amount string) error {
	_, err := tx.Exec(ctx, `
		UPDATE seller_balances SET pending_amount = pending_amount + $1, updated_at = NOW() WHERE seller_id = $2
	`, amount, sellerID)
	if err != nil {
		return fmt.Errorf("credit seller %d pending balance: %w", sellerID, err)
	}
	return nil
}

// ClearCartItems empties the user's cart — the very last write in the
// order transaction, so it only takes effect if everything else committed
// (Stage 6 §33).
func (r *OrderRepository) ClearCartItems(ctx context.Context, tx pgx.Tx, userID int64) error {
	_, err := tx.Exec(ctx, `
		DELETE FROM cart_items ci USING carts c
		WHERE ci.cart_id = c.id AND c.user_id = $1
	`, userID)
	if err != nil {
		return fmt.Errorf("clear cart for user %d: %w", userID, err)
	}
	return nil
}

// --- Read-side (plain pool, no transaction) ---

const orderSummarySelect = `
	o.id, o.status, o.total::text, o.currency, o.created_at
`

// ListOrders returns the user's orders newest-first, each with a small
// items preview — two queries total (orders, then all their items),
// never N+1 (Stage 6 §30).
func (r *OrderRepository) ListOrders(ctx context.Context, userID int64) ([]models.OrderSummary, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+orderSummarySelect+`
		FROM orders o
		WHERE o.user_id = $1
		ORDER BY o.created_at DESC, o.id DESC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("list orders for user %d: %w", userID, err)
	}
	defer rows.Close()

	summaries := []models.OrderSummary{}
	ids := []int64{}
	index := map[int64]int{}
	for rows.Next() {
		var s models.OrderSummary
		if err := rows.Scan(&s.ID, &s.Status, &s.Total, &s.Currency, &s.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan order summary: %w", err)
		}
		s.OrderNumber = formatOrderNumber(s.ID, s.CreatedAt)
		s.ItemsPreview = []models.OrderItemPreview{}
		index[s.ID] = len(summaries)
		ids = append(ids, s.ID)
		summaries = append(summaries, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate orders: %w", err)
	}
	if len(ids) == 0 {
		return summaries, nil
	}

	itemRows, err := r.pool.Query(ctx, `
		SELECT oi.order_id, oi.product_name, oi.quantity,
			(SELECT pi.url FROM product_images pi WHERE pi.product_id = oi.product_id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1)
		FROM order_items oi
		WHERE oi.order_id = ANY($1)
		ORDER BY oi.id ASC
	`, ids)
	if err != nil {
		return nil, fmt.Errorf("list order items preview: %w", err)
	}
	defer itemRows.Close()

	for itemRows.Next() {
		var orderID int64
		var preview models.OrderItemPreview
		if err := itemRows.Scan(&orderID, &preview.ProductName, &preview.Quantity, &preview.PrimaryImage); err != nil {
			return nil, fmt.Errorf("scan order item preview: %w", err)
		}
		i, ok := index[orderID]
		if !ok {
			continue
		}
		summaries[i].ItemCount += preview.Quantity
		summaries[i].ItemsPreview = append(summaries[i].ItemsPreview, preview)
	}
	if err := itemRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate order item previews: %w", err)
	}

	return summaries, nil
}

// GetOrderDetail returns one order, scoped to userID — an order id
// belonging to another user is indistinguishable from a nonexistent one
// (Stage 6 §53, same principle as Stage 5's cart/address ownership checks).
// City/street/house are COALESCEd to "" because the Stage 2 seed's demo
// orders predate the Stage 6 migration that added these columns and are
// genuinely NULL for those rows — every order Stage 6 itself creates
// always populates them (AddressService requires all three).
func (r *OrderRepository) GetOrderDetail(ctx context.Context, userID, orderID int64) (*models.OrderDetail, error) {
	var d models.OrderDetail
	err := r.pool.QueryRow(ctx, `
		SELECT id, status, created_at, subtotal::text, discount_total::text, delivery_total::text, total::text, currency,
			delivery_title, COALESCE(delivery_city, ''), COALESCE(delivery_street, ''), COALESCE(delivery_house, ''), delivery_apartment, delivery_postal_code
		FROM orders
		WHERE id = $1 AND user_id = $2
	`, orderID, userID).Scan(
		&d.ID, &d.Status, &d.CreatedAt, &d.Subtotal, &d.DiscountTotal, &d.DeliveryTotal, &d.Total, &d.Currency,
		&d.Delivery.Title, &d.Delivery.City, &d.Delivery.Street, &d.Delivery.House, &d.Delivery.Apartment, &d.Delivery.PostalCode,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ORDER_NOT_FOUND", "Order not found")
		}
		return nil, fmt.Errorf("load order %d: %w", orderID, err)
	}
	d.OrderNumber = formatOrderNumber(d.ID, d.CreatedAt)

	itemRows, err := r.pool.Query(ctx, `
		SELECT oi.product_id, oi.product_name, oi.quantity, oi.unit_price::text, oi.total_price::text, s.name,
			(SELECT pi.url FROM product_images pi WHERE pi.product_id = oi.product_id ORDER BY pi.is_primary DESC, pi.sort_order ASC, pi.id ASC LIMIT 1)
		FROM order_items oi
		JOIN sellers s ON s.id = oi.seller_id
		WHERE oi.order_id = $1
		ORDER BY oi.id ASC
	`, orderID)
	if err != nil {
		return nil, fmt.Errorf("load order items for order %d: %w", orderID, err)
	}
	defer itemRows.Close()

	d.Items = []models.OrderItemDetail{}
	for itemRows.Next() {
		var it models.OrderItemDetail
		if err := itemRows.Scan(&it.ProductID, &it.ProductName, &it.Quantity, &it.UnitPrice, &it.TotalPrice, &it.SellerName, &it.PrimaryImage); err != nil {
			return nil, fmt.Errorf("scan order item: %w", err)
		}
		d.Items = append(d.Items, it)
	}
	if err := itemRows.Err(); err != nil {
		return nil, fmt.Errorf("iterate order items: %w", err)
	}

	var payment models.OrderPaymentSummary
	err = r.pool.QueryRow(ctx, `
		SELECT provider, status FROM payments WHERE order_id = $1 ORDER BY id DESC LIMIT 1
	`, orderID).Scan(&payment.Provider, &payment.Status)
	if err == nil {
		d.Payment = &payment
	} else if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("load payment for order %d: %w", orderID, err)
	}

	return &d, nil
}
