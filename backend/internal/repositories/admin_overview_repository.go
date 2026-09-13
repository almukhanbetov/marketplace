package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type AdminOverviewRepository struct {
	pool *pgxpool.Pool
}

func NewAdminOverviewRepository(pool *pgxpool.Pool) *AdminOverviewRepository {
	return &AdminOverviewRepository{pool: pool}
}

// relevantOrderStatuses is the single definition of "an order that counts
// toward GMV/marketplace revenue" (Stage 8 §5): paid and everything after
// it in the fulfillment lifecycle, excluding new/confirmed (not yet paid)
// and cancelled/returned.
const relevantOrderStatuses = `('paid', 'processing', 'shipped', 'delivered')`

// GetSummary computes every admin overview metric in one round trip via
// scalar subqueries, each documented with the exact rule it applies (Stage
// 8 §4/§5) — mirrors SellerDashboardRepository.GetSummary's shape.
func (r *AdminOverviewRepository) GetSummary(ctx context.Context) (*models.AdminOverviewSummary, error) {
	query := fmt.Sprintf(`
		SELECT
			COALESCE((SELECT SUM(total) FROM orders WHERE status IN %[1]s), 0)::text AS gmv,
			(SELECT COUNT(*) FROM orders) AS orders_total,
			(SELECT COUNT(*) FROM orders WHERE created_at >= CURRENT_DATE) AS orders_today,
			(SELECT COUNT(*) FROM orders WHERE status IN %[1]s) AS relevant_order_count,
			(SELECT COUNT(*) FROM users WHERE role = 'customer') AS customers_total,
			(SELECT COUNT(*) FROM sellers) AS sellers_total,
			(SELECT COUNT(*) FROM sellers WHERE is_active = TRUE) AS active_sellers,
			(SELECT COUNT(*) FROM products) AS products_total,
			(SELECT COUNT(*) FROM products WHERE is_active = TRUE) AS active_products,
			(SELECT COUNT(*) FROM seller_offers WHERE is_active = TRUE) AS active_offers,
			COALESCE((
				SELECT SUM(c.amount)
				FROM commissions c
				JOIN order_items oi ON oi.id = c.order_item_id
				JOIN orders o ON o.id = oi.order_id
				WHERE o.status IN %[1]s
			), 0)::text AS marketplace_revenue,
			(SELECT COUNT(*) FROM payouts WHERE status = 'pending') AS pending_payouts,
			COALESCE((SELECT SUM(amount) FROM payouts WHERE status = 'pending'), 0)::text AS pending_payout_amount,
			(SELECT COUNT(*) FROM reviews) AS reviews_total,
			(SELECT COUNT(*) FROM reviews WHERE is_visible = FALSE) AS hidden_reviews,
			COALESCE((SELECT SUM(total) FROM orders WHERE status IN %[1]s AND created_at >= CURRENT_DATE), 0)::text AS sales_today,
			(SELECT COUNT(*) FROM users WHERE created_at >= CURRENT_DATE) AS new_users_today
	`, relevantOrderStatuses)

	var (
		s                   models.AdminOverviewSummary
		gmv                 string
		relevantOrderCount  int
		marketplaceRevenue  string
		pendingPayoutAmount string
		salesToday          string
	)
	err := r.pool.QueryRow(ctx, query).Scan(
		&gmv, &s.OrdersTotal, &s.OrdersToday, &relevantOrderCount,
		&s.CustomersTotal, &s.SellersTotal, &s.ActiveSellers,
		&s.ProductsTotal, &s.ActiveProducts, &s.ActiveOffers,
		&marketplaceRevenue, &s.PendingPayouts, &pendingPayoutAmount,
		&s.ReviewsTotal, &s.HiddenReviews, &salesToday, &s.NewUsersToday,
	)
	if err != nil {
		return nil, fmt.Errorf("query admin overview: %w", err)
	}

	s.GMV = models.Money(gmv)
	s.MarketplaceRevenue = models.Money(marketplaceRevenue)
	s.PendingPayoutAmount = models.Money(pendingPayoutAmount)
	s.SalesToday = models.Money(salesToday)

	// AverageOrderValue = GMV / relevantOrderCount (Stage 8 §5) — never
	// OrdersTotal, which counts every order regardless of status.
	if relevantOrderCount > 0 {
		s.AverageOrderValue = models.Money(centsToMoney(moneyToCents(gmv) / int64(relevantOrderCount)))
	} else {
		s.AverageOrderValue = models.Money("0.00")
	}

	return &s, nil
}
