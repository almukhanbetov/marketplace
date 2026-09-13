package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type SellerFinanceRepository struct {
	pool *pgxpool.Pool
}

func NewSellerFinanceRepository(pool *pgxpool.Pool) *SellerFinanceRepository {
	return &SellerFinanceRepository{pool: pool}
}

// GetSummary reuses the exact same nonCancelledOrderItemsCTE inclusion
// rule as the dashboard (Stage 7 §5) so "sales" never means something
// subtly different in two places. gross - commission == net always,
// because seller_amount was itself derived by subtraction at order-
// creation time (Stage 6) — summing that invariant preserves it (§19).
func (r *SellerFinanceRepository) GetSummary(ctx context.Context, sellerID int64) (*models.SellerFinanceSummary, error) {
	query := fmt.Sprintf(`
		WITH %s
		SELECT
			COALESCE(SUM(total_price), 0)::text,
			COALESCE(SUM(commission_amount), 0)::text,
			COALESCE(SUM(seller_amount), 0)::text
		FROM seller_order_items
	`, nonCancelledOrderItemsCTE)

	var gross, commission, net string
	if err := r.pool.QueryRow(ctx, query, sellerID).Scan(&gross, &commission, &net); err != nil {
		return nil, fmt.Errorf("load finance summary for seller %d: %w", sellerID, err)
	}

	var pending, available string
	err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(pending_amount, 0)::text, COALESCE(available_amount, 0)::text
		FROM seller_balances WHERE seller_id = $1
	`, sellerID).Scan(&pending, &available)
	if err != nil {
		// A seller with no balances row yet (shouldn't happen post-seed,
		// but a fresh seller created outside the seed script would hit
		// this) — treat as zero rather than failing the whole dashboard.
		pending, available = "0.00", "0.00"
	}

	var paidOut string
	if err := r.pool.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount), 0)::text FROM payouts WHERE seller_id = $1 AND status = 'paid'
	`, sellerID).Scan(&paidOut); err != nil {
		return nil, fmt.Errorf("load paid-out total for seller %d: %w", sellerID, err)
	}

	return &models.SellerFinanceSummary{
		GrossSales:       models.Money(gross),
		CommissionTotal:  models.Money(commission),
		SellerNetTotal:   models.Money(net),
		PendingBalance:   models.Money(pending),
		AvailableBalance: models.Money(available),
		PaidOutTotal:     models.Money(paidOut),
	}, nil
}
