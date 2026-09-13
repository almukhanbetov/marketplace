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

// Payout service tests are dedicated to seller 7 (SportZone) — already
// used by order_service_test.go's concurrency test, but only for
// pending_amount (via inventory/checkout), never available_amount, so
// this file's available_amount mutations can't collide with it (both run
// sequentially in this same package regardless, but keeping the exact
// column non-overlapping means the two tests' assertions can never be
// order-dependent). No other package touches seller 7's balance at all.
const payoutSvcTestSellerID = int64(7)

func newPayoutTestService(pool *pgxpool.Pool) *services.PayoutService {
	return services.NewPayoutService(
		repositories.NewPayoutRepository(pool),
		repositories.NewSellerRepository(pool),
	)
}

func setPayoutSvcAvailableBalance(t *testing.T, pool *pgxpool.Pool, amount string) func() {
	t.Helper()
	ctx := context.Background()
	var before string
	if err := pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutSvcTestSellerID).Scan(&before); err != nil {
		t.Fatalf("read available_amount: %v", err)
	}
	if _, err := pool.Exec(ctx, `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, amount, payoutSvcTestSellerID); err != nil {
		t.Fatalf("set available_amount: %v", err)
	}
	return func() {
		if _, err := pool.Exec(context.Background(), `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, before, payoutSvcTestSellerID); err != nil {
			t.Errorf("restore available_amount: %v", err)
		}
	}
}

func deleteTestPayoutsSvc(t *testing.T, pool *pgxpool.Pool, keys ...string) {
	t.Helper()
	for _, key := range keys {
		if _, err := pool.Exec(context.Background(), `DELETE FROM payouts WHERE seller_id = $1 AND idempotency_key = $2`, payoutSvcTestSellerID, key); err != nil {
			t.Errorf("cleanup payout key %q: %v", key, err)
		}
	}
}

func uniquePayoutSvcTestKey(name string) string {
	return name + "-" + time.Now().Format("20060102T150405.000000000")
}

// TestPayoutService_Create_NegativeAmount_Rejected covers Stage 7 §53:
// negative and zero amounts are rejected before ever touching the DB.
func TestPayoutService_Create_NegativeAmount_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "-100.00", IdempotencyKey: uniquePayoutSvcTestKey("svc-negative")})
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Create(amount=-100.00) error = %v, want *models.ValidationError", err)
	}
}

func TestPayoutService_Create_ZeroAmount_Rejected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "0.00", IdempotencyKey: uniquePayoutSvcTestKey("svc-zero")})
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("Create(amount=0.00) error = %v, want *models.ValidationError", err)
	}
}

// TestPayoutService_Create_CrossSellerIsolation covers Stage 7 §29: a
// payout request against an unknown/mismatched seller id must never
// succeed silently.
func TestPayoutService_Create_CrossSellerIsolation(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	_, err := service.Create(ctx, 99999999, models.CreatePayoutInput{Amount: "100.00", IdempotencyKey: uniquePayoutSvcTestKey("svc-unknown-seller")})
	if err == nil {
		t.Fatal("expected an error for an unknown seller id, got nil")
	}
}

// TestPayoutService_Create_IdempotentDoubleSubmit covers Stage 7 §24: the
// same seller+Idempotency-Key submitted twice returns the same payout, and
// available_amount is only ever decremented once.
func TestPayoutService_Create_IdempotentDoubleSubmit(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	restore := setPayoutSvcAvailableBalance(t, pool, "50000.00")
	t.Cleanup(restore)

	key := uniquePayoutSvcTestKey("svc-idempotent")
	t.Cleanup(func() { deleteTestPayoutsSvc(t, pool, key) })

	first, err := service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "20000.00", IdempotencyKey: key})
	if err != nil {
		t.Fatalf("first Create() error = %v", err)
	}
	second, err := service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "20000.00", IdempotencyKey: key})
	if err != nil {
		t.Fatalf("second (replayed) Create() error = %v", err)
	}
	if second.ID != first.ID {
		t.Errorf("replayed payout id = %d, want the same payout %d", second.ID, first.ID)
	}

	var count int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM payouts WHERE seller_id = $1 AND idempotency_key = $2`, payoutSvcTestSellerID, key).Scan(&count)
	if count != 1 {
		t.Errorf("expected exactly 1 payout row for a double-submitted key, got %d", count)
	}

	var available string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutSvcTestSellerID).Scan(&available)
	if available != "30000.00" {
		t.Errorf("available_amount after a double-submitted 20000.00 payout = %s, want 30000.00 (decremented once, not twice)", available)
	}
}

// TestPayoutService_Create_InsufficientBalance covers Stage 7 §21.
func TestPayoutService_Create_InsufficientBalance(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	restore := setPayoutSvcAvailableBalance(t, pool, "5000.00")
	t.Cleanup(restore)

	key := uniquePayoutSvcTestKey("svc-insufficient")
	t.Cleanup(func() { deleteTestPayoutsSvc(t, pool, key) })

	_, err := service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "6000.00", IdempotencyKey: key})
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "INSUFFICIENT_AVAILABLE_BALANCE" {
		t.Errorf("Create() error = %v, want *models.ConflictError{INSUFFICIENT_AVAILABLE_BALANCE}", err)
	}
}

// TestPayoutService_ConcurrentRequests_CannotOverdraw re-proves Stage 7
// §53's concurrency requirement at the service layer (not just the
// repository layer): available=100000, two simultaneous 80000 requests,
// exactly one succeeds, available_amount never goes negative.
func TestPayoutService_ConcurrentRequests_CannotOverdraw(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newPayoutTestService(pool)
	ctx := context.Background()

	restore := setPayoutSvcAvailableBalance(t, pool, "100000.00")
	t.Cleanup(restore)

	keyA := uniquePayoutSvcTestKey("svc-concurrent-a")
	keyB := uniquePayoutSvcTestKey("svc-concurrent-b")
	t.Cleanup(func() { deleteTestPayoutsSvc(t, pool, keyA, keyB) })

	var wg sync.WaitGroup
	errs := make([]error, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		_, errs[0] = service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "80000.00", IdempotencyKey: keyA})
	}()
	go func() {
		defer wg.Done()
		_, errs[1] = service.Create(ctx, payoutSvcTestSellerID, models.CreatePayoutInput{Amount: "80000.00", IdempotencyKey: keyB})
	}()
	wg.Wait()

	successes, insufficientFailures := 0, 0
	for _, err := range errs {
		if err == nil {
			successes++
		} else if ce, ok := err.(*models.ConflictError); ok && ce.Code == "INSUFFICIENT_AVAILABLE_BALANCE" {
			insufficientFailures++
		} else {
			t.Errorf("unexpected error from concurrent Create: %v", err)
		}
	}
	if successes != 1 {
		t.Errorf("expected exactly 1 successful payout, got %d", successes)
	}
	if insufficientFailures != 1 {
		t.Errorf("expected exactly 1 INSUFFICIENT_AVAILABLE_BALANCE failure, got %d", insufficientFailures)
	}

	var finalAvailable string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutSvcTestSellerID).Scan(&finalAvailable)
	if finalAvailable != "20000.00" {
		t.Errorf("final available_amount = %s, want exactly 20000.00", finalAvailable)
	}
}
