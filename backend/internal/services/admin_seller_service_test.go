package services_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

func newAdminSellerTestService(pool *pgxpool.Pool) *services.AdminSellerService {
	return services.NewAdminSellerService(repositories.NewAdminSellerRepository(pool))
}

// TestAdminSellerService_UpdateStatus_PublicCatalogRegression covers
// Stage 8 §11/§64: deactivating a seller hides their offers from the
// public catalog (via Stage 3's existing valid_offers rule) without
// deleting any offer; reactivating restores them. Uses seller 3
// (StyleHub) — untouched by any other test's mutations in any package.
func TestAdminSellerService_UpdateStatus_PublicCatalogRegression(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminSellerTestService(pool)
	ctx := context.Background()

	const sellerID = int64(3)

	var offerID, productID int64
	if err := pool.QueryRow(ctx, `SELECT id, product_id FROM seller_offers WHERE seller_id = $1 AND is_active = TRUE LIMIT 1`, sellerID).Scan(&offerID, &productID); err != nil {
		t.Fatalf("find an active offer for seller %d: %v", sellerID, err)
	}

	t.Cleanup(func() {
		if err := service.UpdateStatus(context.Background(), sellerID, true); err != nil {
			t.Errorf("cleanup: reactivate seller %d: %v", sellerID, err)
		}
	})

	offerVisible := func() bool {
		var found bool
		err := pool.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM seller_offers so
				JOIN sellers s ON s.id = so.seller_id AND s.is_active = TRUE
				JOIN products p ON p.id = so.product_id AND p.is_active = TRUE
				JOIN inventory i ON i.seller_offer_id = so.id AND i.available_quantity > 0
				WHERE so.id = $1 AND so.is_active = TRUE
			)
		`, offerID).Scan(&found)
		if err != nil {
			t.Fatalf("check offer visibility: %v", err)
		}
		return found
	}

	if !offerVisible() {
		t.Fatal("setup: offer should be publicly visible before deactivating the seller")
	}

	if err := service.UpdateStatus(ctx, sellerID, false); err != nil {
		t.Fatalf("UpdateStatus(false) error = %v", err)
	}
	if offerVisible() {
		t.Error("offer still publicly visible after deactivating its seller")
	}

	var stillExists bool
	pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM seller_offers WHERE id = $1)`, offerID).Scan(&stillExists)
	if !stillExists {
		t.Error("offer was deleted, not just hidden, after deactivating its seller")
	}

	if err := service.UpdateStatus(ctx, sellerID, true); err != nil {
		t.Fatalf("UpdateStatus(true) error = %v", err)
	}
	if !offerVisible() {
		t.Error("offer not visible again after reactivating its seller")
	}
}

func TestAdminSellerService_UpdateVerification(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminSellerTestService(pool)
	repo := repositories.NewAdminSellerRepository(pool)
	ctx := context.Background()

	const sellerID = int64(3) // StyleHub
	var original bool
	pool.QueryRow(ctx, `SELECT is_verified FROM sellers WHERE id = $1`, sellerID).Scan(&original)
	t.Cleanup(func() {
		if err := service.UpdateVerification(context.Background(), sellerID, original); err != nil {
			t.Errorf("cleanup: restore verification: %v", err)
		}
	})

	if err := service.UpdateVerification(ctx, sellerID, !original); err != nil {
		t.Fatalf("UpdateVerification() error = %v", err)
	}
	detail, err := repo.GetDetail(ctx, sellerID)
	if err != nil {
		t.Fatalf("GetDetail() error = %v", err)
	}
	if detail.IsVerified != !original {
		t.Errorf("IsVerified = %v, want %v", detail.IsVerified, !original)
	}
	if detail.AccountEmail == nil {
		t.Error("expected a non-nil account email in the safe user summary")
	}
}

func TestAdminSellerService_UpdateStatus_UnknownSeller_NotFound(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	service := newAdminSellerTestService(pool)

	err := service.UpdateStatus(context.Background(), 99999999, false)
	if err != models.ErrNotFound {
		t.Errorf("UpdateStatus(unknown) error = %v, want models.ErrNotFound", err)
	}
}
