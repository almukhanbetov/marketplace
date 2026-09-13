package repositories_test

import (
	"context"
	"strconv"
	"strings"
	"testing"

	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// moneyToCentsForRepoTest mirrors order_service_test.go's helper — a
// different package can't import an internal _test.go helper from
// another, so each package keeps its own copy (established convention).
func moneyToCentsForRepoTest(t *testing.T, s string) int64 {
	t.Helper()
	if s == "" {
		return 0
	}
	whole, frac, _ := strings.Cut(s, ".")
	w, err := strconv.ParseInt(whole, 10, 64)
	if err != nil {
		t.Fatalf("parse money %q: %v", s, err)
	}
	frac = (frac + "00")[:2]
	f, err := strconv.ParseInt(frac, 10, 64)
	if err != nil {
		t.Fatalf("parse money %q: %v", s, err)
	}
	return w*100 + f
}

// TestSellerFinanceRepository_GetSummary_Exactness is the core accounting
// proof for Stage 7 §18/§19: gross_sales - commission_total ==
// seller_net_total exactly (never drifting by even a cent), and
// pending/available match seller_balances directly. Read-only — exercised
// against whichever sellers already have order history, so it can't race
// any other package's mutations.
func TestSellerFinanceRepository_GetSummary_Exactness(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerFinanceRepository(pool)
	ctx := context.Background()

	rows, err := pool.Query(ctx, `SELECT DISTINCT seller_id FROM order_items LIMIT 10`)
	if err != nil {
		t.Fatalf("find sellers with order history: %v", err)
	}
	var sellerIDs []int64
	for rows.Next() {
		var id int64
		rows.Scan(&id)
		sellerIDs = append(sellerIDs, id)
	}
	rows.Close()
	if len(sellerIDs) == 0 {
		t.Fatal("expected at least 1 seller with order history")
	}

	for _, sellerID := range sellerIDs {
		summary, err := repo.GetSummary(ctx, sellerID)
		if err != nil {
			t.Fatalf("GetSummary(%d) error = %v", sellerID, err)
		}

		gross := moneyToCentsForRepoTest(t, string(summary.GrossSales))
		commission := moneyToCentsForRepoTest(t, string(summary.CommissionTotal))
		net := moneyToCentsForRepoTest(t, string(summary.SellerNetTotal))
		if gross-commission != net {
			t.Errorf("seller %d: gross(%d) - commission(%d) = %d cents, want net = %d cents", sellerID, gross, commission, gross-commission, net)
		}

		var pendingWant, availableWant string
		if err := pool.QueryRow(ctx, `SELECT pending_amount::text, available_amount::text FROM seller_balances WHERE seller_id = $1`, sellerID).Scan(&pendingWant, &availableWant); err != nil {
			t.Fatalf("read seller_balances for %d: %v", sellerID, err)
		}
		if string(summary.PendingBalance) != pendingWant {
			t.Errorf("seller %d pending_balance = %s, want %s", sellerID, summary.PendingBalance, pendingWant)
		}
		if string(summary.AvailableBalance) != availableWant {
			t.Errorf("seller %d available_balance = %s, want %s", sellerID, summary.AvailableBalance, availableWant)
		}

		var paidOutWant string
		if err := pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount), 0)::text FROM payouts WHERE seller_id = $1 AND status = 'paid'`, sellerID).Scan(&paidOutWant); err != nil {
			t.Fatalf("read paid payouts for %d: %v", sellerID, err)
		}
		if moneyToCentsForRepoTest(t, string(summary.PaidOutTotal)) != moneyToCentsForRepoTest(t, paidOutWant) {
			t.Errorf("seller %d paid_out_total = %s, want %s", sellerID, summary.PaidOutTotal, paidOutWant)
		}
	}
}
