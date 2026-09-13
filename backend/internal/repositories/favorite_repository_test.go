package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Stage 5 tests use the seeded demo customer aigerim@example.com (user id
// 10 in a freshly-seeded dev DB) and product 25, which none of the three
// demo customers' seeded favorites/cart touch (see seeds/seed_demo.go:
// aigerim's seeded favorites are products 1-5) — so these tests don't
// disturb the fixtures other tests/manual QA rely on, and clean up the one
// row they add.
const demoUserID = int64(10)
const safeProductID = int64(25)

func TestFavoriteRepository_AddListRemove(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewFavoriteRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		_ = repo.Remove(ctx, demoUserID, safeProductID)
	})

	if err := repo.Add(ctx, demoUserID, safeProductID); err != nil {
		t.Fatalf("Add() error = %v", err)
	}

	items, err := repo.List(ctx, demoUserID)
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	found := false
	for _, it := range items {
		if it.ID == safeProductID {
			found = true
			if it.Price == "" {
				t.Errorf("favorite product card has empty price")
			}
		}
	}
	if !found {
		t.Fatalf("expected product %d in favorites list after Add(), got %d items", safeProductID, len(items))
	}

	if err := repo.Remove(ctx, demoUserID, safeProductID); err != nil {
		t.Fatalf("Remove() error = %v", err)
	}
	items, err = repo.List(ctx, demoUserID)
	if err != nil {
		t.Fatalf("List() after remove error = %v", err)
	}
	for _, it := range items {
		if it.ID == safeProductID {
			t.Errorf("product %d still present after Remove()", safeProductID)
		}
	}
}

// TestFavoriteRepository_AddIsIdempotent proves adding the same favorite
// twice never creates a duplicate (user_id, product_id) row (Stage 5 §5) —
// the composite primary key would error on a raw duplicate INSERT, so this
// also confirms the ON CONFLICT DO NOTHING clause is doing its job.
func TestFavoriteRepository_AddIsIdempotent(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewFavoriteRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		_ = repo.Remove(ctx, demoUserID, safeProductID)
	})

	if err := repo.Add(ctx, demoUserID, safeProductID); err != nil {
		t.Fatalf("first Add() error = %v", err)
	}
	if err := repo.Add(ctx, demoUserID, safeProductID); err != nil {
		t.Fatalf("second Add() (duplicate) error = %v, want nil (idempotent)", err)
	}

	var count int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM favorites WHERE user_id = $1 AND product_id = $2`, demoUserID, safeProductID).Scan(&count); err != nil {
		t.Fatalf("count favorites: %v", err)
	}
	if count != 1 {
		t.Errorf("expected exactly 1 favorite row after duplicate Add(), got %d", count)
	}
}

// TestFavoriteRepository_RemoveIsIdempotent proves removing an absent
// favorite is a no-op, not an error (Stage 5 §6).
func TestFavoriteRepository_RemoveIsIdempotent(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewFavoriteRepository(pool)
	ctx := context.Background()

	if err := repo.Remove(ctx, demoUserID, 99999999); err != nil {
		t.Errorf("Remove() of an absent favorite error = %v, want nil", err)
	}
}
