package repositories

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// AdminFinanceRepository covers the two read-only marketplace-wide
// finance views: payments and commissions (Stage 8 §23/§24) — consolidated
// the same way SellerOfferRepository combined offers+inventory, since
// both are simple flat read-only listings with no independent lifecycle.
type AdminFinanceRepository struct {
	pool *pgxpool.Pool
}

func NewAdminFinanceRepository(pool *pgxpool.Pool) *AdminFinanceRepository {
	return &AdminFinanceRepository{pool: pool}
}

func (r *AdminFinanceRepository) ListPayments(ctx context.Context, q models.AdminPaymentQuery) ([]models.AdminPaymentItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Status != "" {
		conditions = append(conditions, "p.status = "+next(q.Status))
	}
	if q.Provider != "" {
		conditions = append(conditions, "p.provider = "+next(q.Provider))
	}
	if q.DateFrom != "" {
		conditions = append(conditions, "p.created_at >= "+next(q.DateFrom)+"::date")
	}
	if q.DateTo != "" {
		conditions = append(conditions, "p.created_at < ("+next(q.DateTo)+"::date + INTERVAL '1 day')")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	countQuery := "SELECT COUNT(*) FROM payments p WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin payments: %w", err)
	}
	if total == 0 {
		return []models.AdminPaymentItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT p.id, p.order_id, p.provider, p.status, p.amount::text, p.currency, p.external_reference, p.created_at
		FROM payments p
		WHERE %s
		ORDER BY p.created_at DESC, p.id DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin payments: %w", err)
	}
	defer rows.Close()

	items := []models.AdminPaymentItem{}
	for rows.Next() {
		var it models.AdminPaymentItem
		var amount string
		if err := rows.Scan(&it.ID, &it.OrderID, &it.Provider, &it.Status, &amount, &it.Currency, &it.ExternalReference, &it.CreatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan admin payment: %w", err)
		}
		it.Amount = models.Money(amount)
		items = append(items, it)
	}
	return items, total, rows.Err()
}

func (r *AdminFinanceRepository) ListCommissions(ctx context.Context, q models.AdminCommissionQuery) ([]models.AdminCommissionItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.SellerID != nil {
		conditions = append(conditions, "c.seller_id = "+next(*q.SellerID))
	}
	if q.DateFrom != "" {
		conditions = append(conditions, "c.created_at >= "+next(q.DateFrom)+"::date")
	}
	if q.DateTo != "" {
		conditions = append(conditions, "c.created_at < ("+next(q.DateTo)+"::date + INTERVAL '1 day')")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	countQuery := "SELECT COUNT(*) FROM commissions c WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin commissions: %w", err)
	}
	if total == 0 {
		return []models.AdminCommissionItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT c.id, c.order_item_id, oi.order_id, c.seller_id, s.name, c.rate::text, c.amount::text, c.created_at
		FROM commissions c
		JOIN order_items oi ON oi.id = c.order_item_id
		JOIN sellers s ON s.id = c.seller_id
		WHERE %s
		ORDER BY c.created_at DESC, c.id DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin commissions: %w", err)
	}
	defer rows.Close()

	items := []models.AdminCommissionItem{}
	for rows.Next() {
		var it models.AdminCommissionItem
		var amount string
		if err := rows.Scan(&it.ID, &it.OrderItemID, &it.OrderID, &it.SellerID, &it.SellerName, &it.Rate, &amount, &it.CreatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan admin commission: %w", err)
		}
		it.Amount = models.Money(amount)
		items = append(items, it)
	}
	return items, total, rows.Err()
}
