package services_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Admin payout transition tests are dedicated to seller 2 (HomeComfort) —
// untouched by any Stage 5/6/7 test's balance mutations in any package
// (see order_service_test.go for why that isolation matters), so this
// file's available_amount/payouts mutations can't race another package's
// assertions.
const adminPayoutTestSellerID = int64(2)

func newAdminPayoutTestService(pool *pgxpool.Pool) *services.AdminPayoutService {
	return services.NewAdminPayoutService(repositories.NewAdminPayoutRepository(pool))
}

func setAdminPayoutSellerBalance(t *testing.T, pool *pgxpool.Pool, amount string) func() {
	t.Helper()
	ctx := context.Background()
	var before string
	if err := pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&before); err != nil {
		t.Fatalf("read available_amount: %v", err)
	}
	if _, err := pool.Exec(ctx, `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, amount, adminPayoutTestSellerID); err != nil {
		t.Fatalf("set available_amount: %v", err)
	}
	return func() {
		if _, err := pool.Exec(context.Background(), `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, before, adminPayoutTestSellerID); err != nil {
			t.Errorf("restore available_amount: %v", err)
		}
	}
}

// createTestPayout inserts a payout row directly (bypassing PayoutService's
// own available-balance check) with the given status, returning its id and
// a cleanup func. Admin transition tests need to start from an arbitrary
// status, not just "pending" (what a real payout request always creates).
func createTestPayout(t *testing.T, pool *pgxpool.Pool, amount string, status models.PayoutStatus) (int64, func()) {
	t.Helper()
	ctx := context.Background()
	var id int64
	key := "admin-payout-test-" + time.Now().Format("20060102T150405.000000000")
	err := pool.QueryRow(ctx, `
		INSERT INTO payouts (seller_id, amount, status, idempotency_key)
		VALUES ($1, $2, $3, $4)
		RETURNING id
	`, adminPayoutTestSellerID, amount, status, key).Scan(&id)
	if err != nil {
		t.Fatalf("create test payout: %v", err)
	}
	return id, func() {
		if _, err := pool.Exec(context.Background(), `DELETE FROM payouts WHERE id = $1`, id); err != nil {
			t.Errorf("cleanup payout %d: %v", id, err)
		}
	}
}

// TestAdminPayoutService_ValidTransitions_PendingToProcessingToPaid covers
// Stage 8 §29/§67: processing -> paid only updates status/processed_at —
// available_amount, already decremented at Stage 7 request time, must
// never be touched again.
func TestAdminPayoutService_ValidTransitions_PendingToProcessingToPaid(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminPayoutTestService(pool)
	ctx := context.Background()

	restore := setAdminPayoutSellerBalance(t, pool, "50000.00")
	t.Cleanup(restore)

	payoutID, cleanupPayout := createTestPayout(t, pool, "20000.00", models.PayoutStatusPending)
	t.Cleanup(cleanupPayout)

	p, err := service.UpdateStatus(ctx, payoutID, models.PayoutStatusProcessing)
	if err != nil {
		t.Fatalf("pending->processing error = %v", err)
	}
	if p.Status != models.PayoutStatusProcessing {
		t.Errorf("status = %q, want processing", p.Status)
	}
	if p.ProcessedAt != nil {
		t.Errorf("processing transition should not set processed_at yet, got %v", p.ProcessedAt)
	}

	var availableAfterProcessing string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&availableAfterProcessing)
	if availableAfterProcessing != "50000.00" {
		t.Errorf("available_amount after pending->processing = %s, want unchanged 50000.00", availableAfterProcessing)
	}

	p, err = service.UpdateStatus(ctx, payoutID, models.PayoutStatusPaid)
	if err != nil {
		t.Fatalf("processing->paid error = %v", err)
	}
	if p.Status != models.PayoutStatusPaid {
		t.Errorf("status = %q, want paid", p.Status)
	}
	if p.ProcessedAt == nil {
		t.Error("paid transition should set processed_at")
	}

	var availableAfterPaid string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&availableAfterPaid)
	if availableAfterPaid != "50000.00" {
		t.Errorf("available_amount after processing->paid = %s, want unchanged 50000.00 (no double deduction)", availableAfterPaid)
	}
}

// TestAdminPayoutService_Rejection_RefundsExactlyOnce covers Stage 8
// §27/§28/§66: rejecting a payout refunds its amount back to
// available_amount exactly once; a repeated rejection attempt on the same
// (now-terminal) payout must fail cleanly and never refund a second time.
func TestAdminPayoutService_Rejection_RefundsExactlyOnce(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminPayoutTestService(pool)
	ctx := context.Background()

	restore := setAdminPayoutSellerBalance(t, pool, "100000.00")
	t.Cleanup(restore)

	payoutID, cleanupPayout := createTestPayout(t, pool, "50000.00", models.PayoutStatusPending)
	t.Cleanup(cleanupPayout)

	// available=100000, seller "requests" 50000 (simulated directly, mirroring
	// Stage 7's own request-time decrement, since this test starts from a
	// pending payout that already represents that decrement having happened).
	pool.Exec(ctx, `UPDATE seller_balances SET available_amount = available_amount - 50000.00 WHERE seller_id = $1`, adminPayoutTestSellerID)

	var afterRequest string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&afterRequest)
	if afterRequest != "50000.00" {
		t.Fatalf("setup: available_amount after simulated request = %s, want 50000.00", afterRequest)
	}

	p, err := service.UpdateStatus(ctx, payoutID, models.PayoutStatusRejected)
	if err != nil {
		t.Fatalf("reject error = %v", err)
	}
	if p.Status != models.PayoutStatusRejected {
		t.Errorf("status = %q, want rejected", p.Status)
	}

	var afterReject string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&afterReject)
	if afterReject != "100000.00" {
		t.Errorf("available_amount after reject = %s, want refunded back to 100000.00", afterReject)
	}

	// Repeated reject attempt: rejected is terminal, must be refused and
	// must NOT refund a second time.
	_, err = service.UpdateStatus(ctx, payoutID, models.PayoutStatusRejected)
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "INVALID_PAYOUT_STATUS_TRANSITION" {
		t.Errorf("repeated reject error = %v, want *models.ConflictError{INVALID_PAYOUT_STATUS_TRANSITION}", err)
	}

	var afterSecondAttempt string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&afterSecondAttempt)
	if afterSecondAttempt != "100000.00" {
		t.Errorf("available_amount after a repeated reject attempt = %s, want still 100000.00 (no double refund)", afterSecondAttempt)
	}
}

// TestAdminPayoutService_InvalidTransitions covers Stage 8 §68: paid/
// rejected are terminal, and no transition may skip pending straight to
// paid.
func TestAdminPayoutService_InvalidTransitions(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminPayoutTestService(pool)
	ctx := context.Background()

	restore := setAdminPayoutSellerBalance(t, pool, "10000.00")
	t.Cleanup(restore)

	cases := []struct {
		name string
		from models.PayoutStatus
		to   models.PayoutStatus
	}{
		{"paid_to_pending", models.PayoutStatusPaid, models.PayoutStatusPending},
		{"rejected_to_processing", models.PayoutStatusRejected, models.PayoutStatusProcessing},
		{"paid_to_rejected", models.PayoutStatusPaid, models.PayoutStatusRejected},
		{"pending_to_paid", models.PayoutStatusPending, models.PayoutStatusPaid},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			payoutID, cleanup := createTestPayout(t, pool, "1000.00", tc.from)
			defer cleanup()

			_, err := service.UpdateStatus(ctx, payoutID, tc.to)
			ce, ok := err.(*models.ConflictError)
			if !ok || ce.Code != "INVALID_PAYOUT_STATUS_TRANSITION" {
				t.Errorf("%s->%s error = %v, want *models.ConflictError{INVALID_PAYOUT_STATUS_TRANSITION}", tc.from, tc.to, err)
			}
		})
	}
}

// TestAdminPayoutService_ConcurrentRejectRequests_RefundsOnlyOnce proves
// Stage 8 §30's idempotency-under-concurrency requirement: two goroutines
// racing to reject the same payout must result in exactly one successful
// rejection/refund and one INVALID_PAYOUT_STATUS_TRANSITION failure — the
// payout row's FOR UPDATE lock serializes them.
func TestAdminPayoutService_ConcurrentRejectRequests_RefundsOnlyOnce(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminPayoutTestService(pool)
	ctx := context.Background()

	restore := setAdminPayoutSellerBalance(t, pool, "30000.00")
	t.Cleanup(restore)

	payoutID, cleanupPayout := createTestPayout(t, pool, "10000.00", models.PayoutStatusPending)
	t.Cleanup(cleanupPayout)
	pool.Exec(ctx, `UPDATE seller_balances SET available_amount = available_amount - 10000.00 WHERE seller_id = $1`, adminPayoutTestSellerID)

	var wg sync.WaitGroup
	errs := make([]error, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		_, errs[0] = service.UpdateStatus(ctx, payoutID, models.PayoutStatusRejected)
	}()
	go func() {
		defer wg.Done()
		_, errs[1] = service.UpdateStatus(ctx, payoutID, models.PayoutStatusRejected)
	}()
	wg.Wait()

	successes, invalidTransitions := 0, 0
	for _, err := range errs {
		if err == nil {
			successes++
		} else if ce, ok := err.(*models.ConflictError); ok && ce.Code == "INVALID_PAYOUT_STATUS_TRANSITION" {
			invalidTransitions++
		} else {
			t.Errorf("unexpected error from concurrent reject: %v", err)
		}
	}
	if successes != 1 {
		t.Errorf("expected exactly 1 successful rejection, got %d", successes)
	}
	if invalidTransitions != 1 {
		t.Errorf("expected exactly 1 INVALID_PAYOUT_STATUS_TRANSITION, got %d", invalidTransitions)
	}

	var finalAvailable string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, adminPayoutTestSellerID).Scan(&finalAvailable)
	if finalAvailable != "30000.00" {
		t.Errorf("final available_amount = %s, want exactly 30000.00 (refunded exactly once)", finalAvailable)
	}
}
