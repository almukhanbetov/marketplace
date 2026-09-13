package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// SellerOrderRepository is deliberately read-only (Stage 7 §16/§17): the
// schema has no per-seller fulfillment/suborder entity (no
// order_fulfillments/seller_orders table with one row per
// order_id+seller_id), so a seller cannot independently change an order's
// status — orders.status is one global value shared across every seller on
// a multi-seller order, and letting one seller mutate it would silently
// corrupt the other sellers' and the customer's view of that same order.
// A future stage should introduce that per-seller entity properly rather
// than faking status control here.
type SellerOrderRepository struct {
	pool *pgxpool.Pool
}

func NewSellerOrderRepository(pool *pgxpool.Pool) *SellerOrderRepository {
	return &SellerOrderRepository{pool: pool}
}

// List returns every order containing at least one of this seller's
// lines, with seller-scoped totals only (Stage 7 §13/§14) — never another
// seller's items or amounts, even for the same multi-seller order.
func (r *SellerOrderRepository) List(ctx context.Context, sellerID int64, limit, offset int) ([]models.SellerOrderSummary, int, error) {
	var total int
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(DISTINCT order_id) FROM order_items WHERE seller_id = $1`, sellerID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count seller orders for seller %d: %w", sellerID, err)
	}
	if total == 0 {
		return []models.SellerOrderSummary{}, 0, nil
	}

	rows, err := r.pool.Query(ctx, `
		SELECT o.id, o.status, o.created_at,
			COUNT(oi.id), COALESCE(SUM(oi.total_price), 0)::text,
			COALESCE(SUM(oi.commission_amount), 0)::text, COALESCE(SUM(oi.seller_amount), 0)::text
		FROM order_items oi
		JOIN orders o ON o.id = oi.order_id
		WHERE oi.seller_id = $1
		GROUP BY o.id, o.status, o.created_at
		ORDER BY o.created_at DESC, o.id DESC
		LIMIT $2 OFFSET $3
	`, sellerID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("list seller orders for seller %d: %w", sellerID, err)
	}
	defer rows.Close()

	summaries := []models.SellerOrderSummary{}
	for rows.Next() {
		var s models.SellerOrderSummary
		var gross, commission, net string
		if err := rows.Scan(&s.OrderID, &s.Status, &s.CreatedAt, &s.SellerItemCount, &gross, &commission, &net); err != nil {
			return nil, 0, fmt.Errorf("scan seller order summary: %w", err)
		}
		s.OrderNumber = formatOrderNumber(s.OrderID, s.CreatedAt)
		s.SellerGrossAmount = models.Money(gross)
		s.SellerCommissionAmount = models.Money(commission)
		s.SellerNetAmount = models.Money(net)
		summaries = append(summaries, s)
	}
	return summaries, total, rows.Err()
}

// GetDetail returns only this seller's lines from a customer order, plus
// the delivery snapshot needed for fulfillment. Returns a NotFoundError
// (ORDER_NOT_FOUND) both when the order doesn't exist and when it exists
// but has no line belonging to this seller — identical treatment, so a
// cross-seller order id can never be probed (Stage 7 §29).
func (r *SellerOrderRepository) GetDetail(ctx context.Context, sellerID, orderID int64) (*models.SellerOrderDetail, error) {
	var d models.SellerOrderDetail
	err := r.pool.QueryRow(ctx, `
		SELECT id, status, created_at, delivery_title,
			COALESCE(delivery_city, ''), COALESCE(delivery_street, ''), COALESCE(delivery_house, ''),
			delivery_apartment, delivery_postal_code
		FROM orders
		WHERE id = $1
	`, orderID).Scan(&d.OrderID, &d.Status, &d.CreatedAt, &d.Delivery.Title, &d.Delivery.City, &d.Delivery.Street, &d.Delivery.House, &d.Delivery.Apartment, &d.Delivery.PostalCode)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ORDER_NOT_FOUND", "Order not found")
		}
		return nil, fmt.Errorf("load order %d: %w", orderID, err)
	}
	d.OrderNumber = formatOrderNumber(d.OrderID, d.CreatedAt)

	rows, err := r.pool.Query(ctx, `
		SELECT product_id, product_name, sku, quantity, unit_price::text, total_price::text, commission_amount::text, seller_amount::text
		FROM order_items
		WHERE order_id = $1 AND seller_id = $2
		ORDER BY id ASC
	`, orderID, sellerID)
	if err != nil {
		return nil, fmt.Errorf("load seller items for order %d: %w", orderID, err)
	}
	defer rows.Close()

	d.Items = []models.SellerOrderItemDetail{}
	var grossCents, commissionCents, netCents int64
	for rows.Next() {
		var it models.SellerOrderItemDetail
		var unitPrice, totalPrice, commission, sellerAmount string
		if err := rows.Scan(&it.ProductID, &it.ProductName, &it.SKU, &it.Quantity, &unitPrice, &totalPrice, &commission, &sellerAmount); err != nil {
			return nil, fmt.Errorf("scan seller order item: %w", err)
		}
		it.UnitPrice = models.Money(unitPrice)
		it.TotalPrice = models.Money(totalPrice)
		it.CommissionAmount = models.Money(commission)
		it.SellerAmount = models.Money(sellerAmount)
		grossCents += moneyToCents(totalPrice)
		commissionCents += moneyToCents(commission)
		netCents += moneyToCents(sellerAmount)
		d.Items = append(d.Items, it)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate seller order items: %w", err)
	}
	if len(d.Items) == 0 {
		// The order exists, but this seller has no line on it — same
		// not-found treatment as a nonexistent order (§29).
		return nil, models.NewNotFoundError("ORDER_NOT_FOUND", "Order not found")
	}

	d.SellerGrossAmount = models.Money(centsToMoney(grossCents))
	d.SellerCommissionAmount = models.Money(centsToMoney(commissionCents))
	d.SellerNetAmount = models.Money(centsToMoney(netCents))
	return &d, nil
}
