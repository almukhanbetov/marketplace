package models

// AdminOverviewSummary is GET /admin/overview's payload — marketplace-wide
// aggregates for the admin dashboard landing page.
//
// Metric definitions (Stage 8 §5 — never mix these up):
//   - GMV (gross merchandise value): sum of orders.total for orders whose
//     status is one of paid/processing/shipped/delivered — i.e. orders that
//     were actually paid for and not cancelled/returned. This is the
//     customer-facing total, including the marketplace's commission.
//   - MarketplaceRevenue: sum of commissions.amount for commissions whose
//     order is in that same relevant-status set. This is the marketplace's
//     own cut, never the seller's net and never the full GMV.
//   - AverageOrderValue: GMV / the same relevant order count used to
//     compute GMV (not OrdersTotal, which counts every order regardless of
//     status) — "0.00" if that count is zero.
//   - PendingPayouts / PendingPayoutAmount: count/sum of payouts whose
//     status is exactly "pending" (awaiting admin action) — not
//     "processing", which is already being handled.
type AdminOverviewSummary struct {
	GMV                 Money `json:"gmv"`
	OrdersTotal         int   `json:"orders_total"`
	OrdersToday         int   `json:"orders_today"`
	CustomersTotal      int   `json:"customers_total"`
	SellersTotal        int   `json:"sellers_total"`
	ActiveSellers       int   `json:"active_sellers"`
	ProductsTotal       int   `json:"products_total"`
	ActiveProducts      int   `json:"active_products"`
	ActiveOffers        int   `json:"active_offers"`
	MarketplaceRevenue  Money `json:"marketplace_revenue"`
	PendingPayouts      int   `json:"pending_payouts"`
	PendingPayoutAmount Money `json:"pending_payout_amount"`
	AverageOrderValue   Money `json:"average_order_value"`
	ReviewsTotal        int   `json:"reviews_total"`
	HiddenReviews       int   `json:"hidden_reviews"`
	SalesToday          Money `json:"sales_today"`
	NewUsersToday       int   `json:"new_users_today"`
}
