package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Dedicated to this package — distinct from Stage 5's and the other Stage 6
// packages' (services_test/handlers_test) offer allocations, since
// `go test ./...` runs each package's tests as a separate process against
// the same real dev database (see order_service_test.go's comment).
const repoOrderTestOffer = int64(69) // product 34, seller 2

// TestOrderRepository_DecrementInventory_AtomicGuard exercises the exact
// primitive Stage 6 §15 prescribes: a single conditional UPDATE, not a
// separate SELECT then blind UPDATE.
func TestOrderRepository_DecrementInventory_AtomicGuard(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewOrderRepository(pool)
	ctx := context.Background()

	var original int
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, repoOrderTestOffer).Scan(&original); err != nil {
		t.Fatalf("read original stock: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `UPDATE inventory SET available_quantity = $1 WHERE seller_offer_id = $2`, original, repoOrderTestOffer)
	})

	tx, err := repo.Begin(ctx)
	if err != nil {
		t.Fatalf("Begin() error = %v", err)
	}
	defer tx.Rollback(ctx)

	// A request for more than available must fail cleanly (no error, ok=false).
	ok, err := repo.DecrementInventory(ctx, tx, repoOrderTestOffer, original+1)
	if err != nil {
		t.Fatalf("DecrementInventory(too many) error = %v", err)
	}
	if ok {
		t.Error("DecrementInventory(too many) = true, want false")
	}

	// A request within bounds must succeed and actually decrement.
	ok, err = repo.DecrementInventory(ctx, tx, repoOrderTestOffer, 1)
	if err != nil {
		t.Fatalf("DecrementInventory(1) error = %v", err)
	}
	if !ok {
		t.Fatal("DecrementInventory(1) = false, want true")
	}

	var afterFirstDecrement int
	if err := tx.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, repoOrderTestOffer).Scan(&afterFirstDecrement); err != nil {
		t.Fatalf("read stock mid-transaction: %v", err)
	}
	if afterFirstDecrement != original-1 {
		t.Errorf("stock after decrementing 1 = %d, want %d", afterFirstDecrement, original-1)
	}

	// Requesting exactly the remaining amount must succeed; one more than
	// that must fail — the boundary condition (>=) matters.
	ok, err = repo.DecrementInventory(ctx, tx, repoOrderTestOffer, afterFirstDecrement+1)
	if err != nil {
		t.Fatalf("DecrementInventory(remaining+1) error = %v", err)
	}
	if ok {
		t.Error("DecrementInventory(remaining+1) = true, want false (exceeds what's left)")
	}

	ok, err = repo.DecrementInventory(ctx, tx, repoOrderTestOffer, afterFirstDecrement)
	if err != nil {
		t.Fatalf("DecrementInventory(remaining) error = %v", err)
	}
	if !ok {
		t.Error("DecrementInventory(exactly remaining) = false, want true")
	}

	var final int
	if err := tx.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, repoOrderTestOffer).Scan(&final); err != nil {
		t.Fatalf("read final stock: %v", err)
	}
	if final != 0 {
		t.Errorf("final stock = %d, want 0", final)
	}

	// Rolling back must undo every decrement above — the transaction never
	// committed.
	if err := tx.Rollback(ctx); err != nil {
		t.Fatalf("Rollback() error = %v", err)
	}
	var afterRollback int
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, repoOrderTestOffer).Scan(&afterRollback); err != nil {
		t.Fatalf("read stock after rollback: %v", err)
	}
	if afterRollback != original {
		t.Errorf("stock after rollback = %d, want the original %d (rollback must undo every decrement)", afterRollback, original)
	}
}

// TestOrderRepository_ListOrders_OwnershipScoped confirms two different
// users never see each other's order history (Stage 6 §29/§53).
func TestOrderRepository_ListOrders_OwnershipScoped(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewOrderRepository(pool)
	ctx := context.Background()

	aigerimOrders, err := repo.ListOrders(ctx, 10)
	if err != nil {
		t.Fatalf("ListOrders(10) error = %v", err)
	}
	for _, o := range aigerimOrders {
		detail, err := repo.GetOrderDetail(ctx, 10, o.ID)
		if err != nil {
			t.Fatalf("GetOrderDetail(10, %d) error = %v", o.ID, err)
		}
		if detail.ID != o.ID {
			t.Errorf("GetOrderDetail returned order %d for requested %d", detail.ID, o.ID)
		}

		// The same order id, requested by a different user, must be
		// treated as not found — never leaked cross-user.
		if _, err := repo.GetOrderDetail(ctx, 11, o.ID); err == nil {
			t.Errorf("GetOrderDetail(11, %d) succeeded — order belongs to user 10, must be ORDER_NOT_FOUND for user 11", o.ID)
		}
	}
}

func TestOrderRepository_GetOrderDetail_UnknownOrder(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewOrderRepository(pool)
	ctx := context.Background()

	if _, err := repo.GetOrderDetail(ctx, 10, 99999999); err == nil {
		t.Error("expected an error for an unknown order id, got nil")
	}
}
