package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type SellerDashboardRepository struct {
	pool *pgxpool.Pool
}

func NewSellerDashboardRepository(pool *pgxpool.Pool) *SellerDashboardRepository {
	return &SellerDashboardRepository{pool: pool}
}

// nonCancelledOrderItemsCTE is the single definition of "this seller's
// order items that count toward sales/finance metrics" (Stage 7 §5):
// everything except order_items belonging to a cancelled/returned order.
// Every aggregate query in this file and seller_finance/seller_order
// repositories builds on it so the inclusion rule can never drift.
const nonCancelledOrderItemsCTE = `
	seller_order_items AS (
		SELECT oi.*, o.status AS order_status, o.created_at AS order_created_at
		FROM order_items oi
		JOIN orders o ON o.id = oi.order_id
		WHERE oi.seller_id = $1 AND o.status NOT IN ('cancelled', 'returned')
	)
`

// GetSummary aggregates the dashboard's cards in a single round trip — no
// N+1 (Stage 7 §47). today/total/offers each produce exactly one row, so
// cross-joining them with sellers is safe.
func (r *SellerDashboardRepository) GetSummary(ctx context.Context, sellerID int64) (*models.SellerDashboardSummary, error) {
	query := fmt.Sprintf(`
		WITH %s,
		today AS (
			SELECT COALESCE(SUM(total_price), 0)::text AS sales_today, COUNT(DISTINCT order_id) AS orders_today
			FROM seller_order_items
			WHERE order_created_at >= date_trunc('day', now())
		),
		total AS (
			SELECT COUNT(DISTINCT order_id) AS orders_total FROM seller_order_items
		),
		offers AS (
			SELECT
				COUNT(*) FILTER (WHERE so.is_active) AS active_offers,
				COUNT(*) FILTER (WHERE so.is_active AND COALESCE(inv.available_quantity, 0) <= %d) AS low_stock_offers
			FROM seller_offers so
			LEFT JOIN inventory inv ON inv.seller_offer_id = so.id
			WHERE so.seller_id = $1
		)
		SELECT
			today.sales_today, today.orders_today, total.orders_total,
			COALESCE(sb.pending_amount, 0)::text, COALESCE(sb.available_amount, 0)::text,
			offers.active_offers, offers.low_stock_offers,
			s.rating::float8, s.review_count
		FROM today, total, offers, sellers s
		LEFT JOIN seller_balances sb ON sb.seller_id = s.id
		WHERE s.id = $1
	`, nonCancelledOrderItemsCTE, models.LowStockThreshold)

	var summary models.SellerDashboardSummary
	var salesToday, pendingBalance, availableBalance string
	err := r.pool.QueryRow(ctx, query, sellerID).Scan(
		&salesToday, &summary.OrdersToday, &summary.OrdersTotal,
		&pendingBalance, &availableBalance,
		&summary.ActiveOffers, &summary.LowStockOffers,
		&summary.Rating, &summary.ReviewCount,
	)
	if err != nil {
		return nil, fmt.Errorf("load dashboard summary for seller %d: %w", sellerID, err)
	}
	summary.SalesToday = models.Money(salesToday)
	summary.PendingBalance = models.Money(pendingBalance)
	summary.AvailableBalance = models.Money(availableBalance)
	summary.LowStockThreshold = models.LowStockThreshold
	return &summary, nil
}
