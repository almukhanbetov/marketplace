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

// AdminOrderRepository reads marketplace-wide orders — every seller's
// items on every customer's order are visible here, unlike the seller- or
// customer-scoped views (Stage 8 §20/§21).
type AdminOrderRepository struct {
	pool *pgxpool.Pool
}

func NewAdminOrderRepository(pool *pgxpool.Pool) *AdminOrderRepository {
	return &AdminOrderRepository{pool: pool}
}

var adminOrderSortColumns = map[string]string{
	"":                "o.created_at DESC, o.id DESC",
	"created_at_asc":  "o.created_at ASC, o.id ASC",
	"created_at_desc": "o.created_at DESC, o.id DESC",
	"total_desc":      "o.total DESC, o.id ASC",
	"total_asc":       "o.total ASC, o.id ASC",
}

func (r *AdminOrderRepository) List(ctx context.Context, q models.AdminOrderQuery) ([]models.AdminOrderListItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Status != "" {
		conditions = append(conditions, "o.status = "+next(q.Status))
	}
	if q.UserID != nil {
		conditions = append(conditions, "o.user_id = "+next(*q.UserID))
	}
	if q.DateFrom != "" {
		conditions = append(conditions, "o.created_at >= "+next(q.DateFrom)+"::date")
	}
	if q.DateTo != "" {
		conditions = append(conditions, "o.created_at < ("+next(q.DateTo)+"::date + INTERVAL '1 day')")
	}
	if q.MinTotal != "" {
		conditions = append(conditions, "o.total >= "+next(q.MinTotal)+"::numeric")
	}
	if q.MaxTotal != "" {
		conditions = append(conditions, "o.total <= "+next(q.MaxTotal)+"::numeric")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	orderBy := adminOrderSortColumns[q.Sort]
	if orderBy == "" {
		orderBy = adminOrderSortColumns[""]
	}

	countQuery := "SELECT COUNT(*) FROM orders o WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin orders: %w", err)
	}
	if total == 0 {
		return []models.AdminOrderListItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT
			o.id, o.status, o.total::text, o.currency, o.created_at,
			u.id, u.full_name, u.email, u.phone,
			(SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count,
			(SELECT COUNT(DISTINCT oi.seller_id) FROM order_items oi WHERE oi.order_id = o.id) AS seller_count,
			COALESCE((SELECT pay.status FROM payments pay WHERE pay.order_id = o.id ORDER BY pay.id DESC LIMIT 1), 'none')
		FROM orders o
		JOIN users u ON u.id = o.user_id
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, where, orderBy, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin orders: %w", err)
	}
	defer rows.Close()

	items := []models.AdminOrderListItem{}
	for rows.Next() {
		var it models.AdminOrderListItem
		var total string
		if err := rows.Scan(
			&it.ID, &it.Status, &total, &it.Currency, &it.CreatedAt,
			&it.User.ID, &it.User.FullName, &it.User.Email, &it.User.Phone,
			&it.ItemCount, &it.SellerCount, &it.PaymentStatus,
		); err != nil {
			return nil, 0, fmt.Errorf("scan admin order: %w", err)
		}
		it.Total = models.Money(total)
		it.OrderNumber = formatOrderNumber(it.ID, it.CreatedAt)
		items = append(items, it)
	}
	return items, total, rows.Err()
}

// GetDetail returns the full multi-seller order — every item from every
// seller, plus commission/seller-net amounts (Stage 8 §21: admin-only
// financial visibility). Returns models.ErrNotFound if the order doesn't
// exist.
func (r *AdminOrderRepository) GetDetail(ctx context.Context, id int64) (*models.AdminOrderDetail, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT
			o.id, o.status, o.subtotal::text, o.delivery_total::text, o.commission_total::text, o.total::text, o.currency, o.created_at,
			o.delivery_title, COALESCE(o.delivery_city, ''), COALESCE(o.delivery_street, ''), COALESCE(o.delivery_house, ''),
			o.delivery_apartment, o.delivery_postal_code,
			u.id, u.full_name, u.email, u.phone
		FROM orders o
		JOIN users u ON u.id = o.user_id
		WHERE o.id = $1
	`, id)

	var (
		d                                       models.AdminOrderDetail
		subtotal, deliveryTotal, commission, tt string
	)
	err := row.Scan(
		&d.ID, &d.Status, &subtotal, &deliveryTotal, &commission, &tt, &d.Currency, &d.CreatedAt,
		&d.Delivery.Title, &d.Delivery.City, &d.Delivery.Street, &d.Delivery.House,
		&d.Delivery.Apartment, &d.Delivery.PostalCode,
		&d.User.ID, &d.User.FullName, &d.User.Email, &d.User.Phone,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin order detail %d: %w", id, err)
	}
	d.Subtotal = models.Money(subtotal)
	d.DeliveryTotal = models.Money(deliveryTotal)
	d.CommissionTotal = models.Money(commission)
	d.Total = models.Money(tt)
	d.OrderNumber = formatOrderNumber(d.ID, d.CreatedAt)

	itemRows, err := r.pool.Query(ctx, `
		SELECT
			oi.seller_id, s.name, oi.product_id, oi.product_name, oi.sku, oi.quantity,
			oi.unit_price::text, oi.total_price::text, oi.commission_amount::text, oi.seller_amount::text
		FROM order_items oi
		JOIN sellers s ON s.id = oi.seller_id
		WHERE oi.order_id = $1
		ORDER BY s.name ASC, oi.id ASC
	`, id)
	if err != nil {
		return nil, fmt.Errorf("query admin order items %d: %w", id, err)
	}
	defer itemRows.Close()

	items := []models.AdminOrderItemDetail{}
	for itemRows.Next() {
		var it models.AdminOrderItemDetail
		var unitPrice, totalPrice, commissionAmount, sellerAmount string
		if err := itemRows.Scan(
			&it.SellerID, &it.SellerName, &it.ProductID, &it.ProductName, &it.SKU, &it.Quantity,
			&unitPrice, &totalPrice, &commissionAmount, &sellerAmount,
		); err != nil {
			return nil, fmt.Errorf("scan admin order item: %w", err)
		}
		it.UnitPrice = models.Money(unitPrice)
		it.TotalPrice = models.Money(totalPrice)
		it.CommissionAmount = models.Money(commissionAmount)
		it.SellerAmount = models.Money(sellerAmount)
		items = append(items, it)
	}
	if err := itemRows.Err(); err != nil {
		return nil, err
	}
	d.Items = items

	var provider, status *string
	err = r.pool.QueryRow(ctx, `SELECT provider, status FROM payments WHERE order_id = $1 ORDER BY id DESC LIMIT 1`, id).Scan(&provider, &status)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("query admin order payment %d: %w", id, err)
	}
	if provider != nil {
		d.Payment = &models.OrderPaymentSummary{Provider: models.PaymentProvider(*provider), Status: *status}
	}

	return &d, nil
}
