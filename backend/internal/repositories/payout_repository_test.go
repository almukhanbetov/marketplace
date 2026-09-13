package repositories_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Payout repository tests are dedicated to seller 5 (BeautyLab) — same
// reasoning as sellerOfferTestSellerID above: untouched by any Stage 5/6
// test's balance mutations, and this package's tests all run sequentially
// in one process so reusing it across this file and
// seller_offer_repository_test.go is safe.
const payoutTestSellerID = int64(5)

// setSellerAvailableBalance sets seller_balances.available_amount to an
// exact known value for a test and returns a restore func for
// t.Cleanup — mirrors order_service_test.go's inventory/balance
// save-and-restore pattern (Stage 7 §22 explicitly allows test setup to
// provision available balance this way).
func setSellerAvailableBalance(t *testing.T, pool *pgxpool.Pool, sellerID int64, amount string) func() {
	t.Helper()
	ctx := context.Background()
	var before string
	if err := pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, sellerID).Scan(&before); err != nil {
		t.Fatalf("read available_amount for seller %d: %v", sellerID, err)
	}
	if _, err := pool.Exec(ctx, `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, amount, sellerID); err != nil {
		t.Fatalf("set available_amount for seller %d: %v", sellerID, err)
	}
	return func() {
		if _, err := pool.Exec(context.Background(), `UPDATE seller_balances SET available_amount = $1 WHERE seller_id = $2`, before, sellerID); err != nil {
			t.Errorf("restore available_amount for seller %d: %v", sellerID, err)
		}
	}
}

func deleteTestPayouts(t *testing.T, pool *pgxpool.Pool, sellerID int64, keys ...string) {
	t.Helper()
	for _, key := range keys {
		if _, err := pool.Exec(context.Background(), `DELETE FROM payouts WHERE seller_id = $1 AND idempotency_key = $2`, sellerID, key); err != nil {
			t.Errorf("cleanup payout key %q: %v", key, err)
		}
	}
}

func uniquePayoutTestKey(name string) string {
	return name + "-" + time.Now().Format("20060102T150405.000000000")
}

// TestPayoutRepository_Create_Valid covers Stage 7 §23: a valid request
// decreases available_amount by exactly the requested amount and inserts a
// pending payout.
func TestPayoutRepository_Create_Valid(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewPayoutRepository(pool)
	ctx := context.Background()

	restore := setSellerAvailableBalance(t, pool, payoutTestSellerID, "100000.00")
	t.Cleanup(restore)

	key := uniquePayoutTestKey("repo-valid")
	t.Cleanup(func() { deleteTestPayouts(t, pool, payoutTestSellerID, key) })

	payoutID, err := repo.Create(ctx, payoutTestSellerID, "40000.00", key)
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	payout, err := repo.GetByID(ctx, payoutTestSellerID, payoutID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if payout.Status != models.PayoutStatusPending {
		t.Errorf("payout.Status = %q, want pending", payout.Status)
	}
	if payout.Amount != "40000.00" {
		t.Errorf("payout.Amount = %s, want 40000.00", payout.Amount)
	}

	var availableAfter string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutTestSellerID).Scan(&availableAfter)
	if availableAfter != "60000.00" {
		t.Errorf("available_amount after payout = %s, want 60000.00", availableAfter)
	}
}

// TestPayoutRepository_Create_InsufficientBalance covers Stage 7 §21/§22:
// a payout may only draw from available_amount — rejected with
// INSUFFICIENT_AVAILABLE_BALANCE when insufficient, and the balance must
// be left completely untouched (transaction rolled back).
func TestPayoutRepository_Create_InsufficientBalance(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewPayoutRepository(pool)
	ctx := context.Background()

	restore := setSellerAvailableBalance(t, pool, payoutTestSellerID, "10000.00")
	t.Cleanup(restore)

	key := uniquePayoutTestKey("repo-insufficient")
	t.Cleanup(func() { deleteTestPayouts(t, pool, payoutTestSellerID, key) })

	_, err := repo.Create(ctx, payoutTestSellerID, "50000.00", key)
	if err == nil {
		t.Fatal("expected an error for a payout exceeding available balance, got nil")
	}
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "INSUFFICIENT_AVAILABLE_BALANCE" {
		t.Errorf("Create() error = %v, want *models.ConflictError{INSUFFICIENT_AVAILABLE_BALANCE}", err)
	}

	var availableAfter string
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutTestSellerID).Scan(&availableAfter)
	if availableAfter != "10000.00" {
		t.Errorf("available_amount changed after a rejected payout: %s, want unchanged 10000.00", availableAfter)
	}
}

// TestPayoutRepository_Create_ZeroAvailable_RejectsEvenWithPending covers
// Stage 7 §21: if available_amount is 0, a payout must be rejected even
// though pending_amount might be nonzero — pending is never a payout
// source.
func TestPayoutRepository_Create_ZeroAvailable_RejectsEvenWithPending(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewPayoutRepository(pool)
	ctx := context.Background()

	restore := setSellerAvailableBalance(t, pool, payoutTestSellerID, "0.00")
	t.Cleanup(restore)

	key := uniquePayoutTestKey("repo-zero-available")
	t.Cleanup(func() { deleteTestPayouts(t, pool, payoutTestSellerID, key) })

	_, err := repo.Create(ctx, payoutTestSellerID, "1.00", key)
	ce, ok := err.(*models.ConflictError)
	if !ok || ce.Code != "INSUFFICIENT_AVAILABLE_BALANCE" {
		t.Errorf("Create() with available=0 error = %v, want *models.ConflictError{INSUFFICIENT_AVAILABLE_BALANCE}", err)
	}
}

// TestPayoutRepository_Create_DuplicateIdempotencyKey_UniqueViolation
// covers Stage 7 §24: the DB's own UNIQUE(seller_id, idempotency_key)
// partial index is what ultimately guarantees "same seller+key => one
// payout only" under a race — this proves the constraint itself fires.
func TestPayoutRepository_Create_DuplicateIdempotencyKey_UniqueViolation(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewPayoutRepository(pool)
	ctx := context.Background()

	restore := setSellerAvailableBalance(t, pool, payoutTestSellerID, "100000.00")
	t.Cleanup(restore)

	key := uniquePayoutTestKey("repo-dup-key")
	t.Cleanup(func() { deleteTestPayouts(t, pool, payoutTestSellerID, key) })

	if _, err := repo.Create(ctx, payoutTestSellerID, "1000.00", key); err != nil {
		t.Fatalf("first Create() error = %v", err)
	}
	_, err := repo.Create(ctx, payoutTestSellerID, "1000.00", key)
	if err == nil {
		t.Fatal("expected a unique-violation error for a duplicate idempotency key, got nil")
	}
	if !repositories.IsUniqueViolation(err) {
		t.Errorf("Create() error = %v, want a unique-violation error", err)
	}
}

// TestPayoutRepository_ConcurrentRequests_CannotOverdraw is the critical
// concurrency proof Stage 7 §53 explicitly requires: with
// available_amount = 100000.00, two simultaneous 80000.00 payout requests
// must resolve to exactly one success and one INSUFFICIENT_AVAILABLE_BALANCE
// failure — available_amount must never go negative, proving the
// `SELECT ... FOR UPDATE` row lock in PayoutRepository.Create actually
// serializes concurrent payout requests rather than racing.
func TestPayoutRepository_ConcurrentRequests_CannotOverdraw(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewPayoutRepository(pool)
	ctx := context.Background()

	restore := setSellerAvailableBalance(t, pool, payoutTestSellerID, "100000.00")
	t.Cleanup(restore)

	keyA := uniquePayoutTestKey("repo-concurrent-a")
	keyB := uniquePayoutTestKey("repo-concurrent-b")
	t.Cleanup(func() { deleteTestPayouts(t, pool, payoutTestSellerID, keyA, keyB) })

	var wg sync.WaitGroup
	errs := make([]error, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		_, errs[0] = repo.Create(ctx, payoutTestSellerID, "80000.00", keyA)
	}()
	go func() {
		defer wg.Done()
		_, errs[1] = repo.Create(ctx, payoutTestSellerID, "80000.00", keyB)
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
	pool.QueryRow(ctx, `SELECT available_amount::text FROM seller_balances WHERE seller_id = $1`, payoutTestSellerID).Scan(&finalAvailable)
	if finalAvailable != "20000.00" {
		t.Errorf("final available_amount = %s, want exactly 20000.00 (100000 - one successful 80000 payout)", finalAvailable)
	}
}
