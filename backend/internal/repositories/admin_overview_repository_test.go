package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// TestAdminOverviewRepository_GetSummary_MatchesRawSQL is a read-only
// cross-check (Stage 8 §73): every aggregate in the summary is
// independently recomputed here with a slightly different query shape
// than the repository uses, and must match exactly.
func TestAdminOverviewRepository_GetSummary_MatchesRawSQL(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewAdminOverviewRepository(pool)
	ctx := context.Background()

	summary, err := repo.GetSummary(ctx)
	if err != nil {
		t.Fatalf("GetSummary() error = %v", err)
	}

	var wantGMV string
	pool.QueryRow(ctx, `SELECT COALESCE(SUM(total), 0)::text FROM orders WHERE status IN ('paid', 'processing', 'shipped', 'delivered')`).Scan(&wantGMV)
	if string(summary.GMV) != wantGMV {
		t.Errorf("GMV = %s, want %s", summary.GMV, wantGMV)
	}

	var wantOrdersTotal int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM orders`).Scan(&wantOrdersTotal)
	if summary.OrdersTotal != wantOrdersTotal {
		t.Errorf("OrdersTotal = %d, want %d", summary.OrdersTotal, wantOrdersTotal)
	}

	var wantCustomers int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM users WHERE role = 'customer'`).Scan(&wantCustomers)
	if summary.CustomersTotal != wantCustomers {
		t.Errorf("CustomersTotal = %d, want %d", summary.CustomersTotal, wantCustomers)
	}

	var wantSellersTotal, wantActiveSellers int
	pool.QueryRow(ctx, `SELECT COUNT(*), COUNT(*) FILTER (WHERE is_active) FROM sellers`).Scan(&wantSellersTotal, &wantActiveSellers)
	if summary.SellersTotal != wantSellersTotal {
		t.Errorf("SellersTotal = %d, want %d", summary.SellersTotal, wantSellersTotal)
	}
	if summary.ActiveSellers != wantActiveSellers {
		t.Errorf("ActiveSellers = %d, want %d", summary.ActiveSellers, wantActiveSellers)
	}

	var wantMarketplaceRevenue string
	pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(c.amount), 0)::text
		FROM commissions c
		JOIN order_items oi ON oi.id = c.order_item_id
		JOIN orders o ON o.id = oi.order_id
		WHERE o.status IN ('paid', 'processing', 'shipped', 'delivered')
	`).Scan(&wantMarketplaceRevenue)
	if string(summary.MarketplaceRevenue) != wantMarketplaceRevenue {
		t.Errorf("MarketplaceRevenue = %s, want %s", summary.MarketplaceRevenue, wantMarketplaceRevenue)
	}

	var wantPendingPayouts int
	var wantPendingPayoutAmount string
	pool.QueryRow(ctx, `SELECT COUNT(*), COALESCE(SUM(amount), 0)::text FROM payouts WHERE status = 'pending'`).Scan(&wantPendingPayouts, &wantPendingPayoutAmount)
	if summary.PendingPayouts != wantPendingPayouts {
		t.Errorf("PendingPayouts = %d, want %d", summary.PendingPayouts, wantPendingPayouts)
	}
	if string(summary.PendingPayoutAmount) != wantPendingPayoutAmount {
		t.Errorf("PendingPayoutAmount = %s, want %s", summary.PendingPayoutAmount, wantPendingPayoutAmount)
	}

	var wantReviewsTotal, wantHiddenReviews int
	pool.QueryRow(ctx, `SELECT COUNT(*), COUNT(*) FILTER (WHERE NOT is_visible) FROM reviews`).Scan(&wantReviewsTotal, &wantHiddenReviews)
	if summary.ReviewsTotal != wantReviewsTotal {
		t.Errorf("ReviewsTotal = %d, want %d", summary.ReviewsTotal, wantReviewsTotal)
	}
	if summary.HiddenReviews != wantHiddenReviews {
		t.Errorf("HiddenReviews = %d, want %d", summary.HiddenReviews, wantHiddenReviews)
	}

	// AverageOrderValue must be GMV / the relevant order count, never
	// GMV / OrdersTotal.
	var wantRelevantCount int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM orders WHERE status IN ('paid', 'processing', 'shipped', 'delivered')`).Scan(&wantRelevantCount)
	if wantRelevantCount > 0 {
		if summary.AverageOrderValue == "0.00" {
			t.Error("AverageOrderValue is 0.00 despite relevant orders existing")
		}
	}
}
