package repositories_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Stage 7 offer/inventory repository tests are dedicated to seller 5
// (BeautyLab) — untouched by any Stage 5/6 test's balance or order
// mutations, so it's safe for this package to create/update/delete
// throwaway offers on it without racing another package's assertions
// (see order_service_test.go for the full explanation of why `go test
// ./...`'s per-package parallelism forces this kind of dedicated
// allocation). Products 1/3/6/8 have no existing seller-5 offer, so
// creating one here can never collide with a seeded SKU.
const sellerOfferTestSellerID = int64(5)

func deleteTestOffer(t *testing.T, pool *pgxpool.Pool, offerID int64) {
	t.Helper()
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `DELETE FROM inventory WHERE seller_offer_id = $1`, offerID); err != nil {
		t.Errorf("cleanup: delete inventory for offer %d: %v", offerID, err)
	}
	if _, err := pool.Exec(ctx, `DELETE FROM seller_offers WHERE id = $1`, offerID); err != nil {
		t.Errorf("cleanup: delete offer %d: %v", offerID, err)
	}
}

func TestSellerOfferRepository_Create_List_Update_Status(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOfferRepository(pool)
	ctx := context.Background()

	offerID, err := repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-TEST-REPO-1", Price: "10000.00", OldPrice: "12000.00", DeliveryDays: 1, Stock: 7,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestOffer(t, pool, offerID) })

	items, total, err := repo.List(ctx, sellerOfferTestSellerID, models.SellerOfferQuery{Search: "SKU-TEST-REPO-1", Limit: 20})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if total != 1 || len(items) != 1 {
		t.Fatalf("List(search=SKU-TEST-REPO-1) total=%d len=%d, want 1/1", total, len(items))
	}
	if items[0].Price != "10000.00" || items[0].AvailableQuantity != 7 || !items[0].IsActive {
		t.Errorf("unexpected offer fields: %+v", items[0])
	}

	if err := repo.Update(ctx, sellerOfferTestSellerID, offerID, models.UpdateOfferInput{
		SKU: "SKU-TEST-REPO-1", Price: "15000.00", OldPrice: "", DeliveryDays: 3,
	}); err != nil {
		t.Fatalf("Update() error = %v", err)
	}
	items, _, err = repo.List(ctx, sellerOfferTestSellerID, models.SellerOfferQuery{Search: "SKU-TEST-REPO-1", Limit: 20})
	if err != nil || len(items) != 1 {
		t.Fatalf("List after update: err=%v len=%d", err, len(items))
	}
	if items[0].Price != "15000.00" || items[0].OldPrice != nil || items[0].DeliveryDays != 3 {
		t.Errorf("update did not persist: %+v", items[0])
	}

	if err := repo.UpdateStatus(ctx, sellerOfferTestSellerID, offerID, false); err != nil {
		t.Fatalf("UpdateStatus(false) error = %v", err)
	}
	active, _, err := repo.List(ctx, sellerOfferTestSellerID, models.SellerOfferQuery{Search: "SKU-TEST-REPO-1", Status: "active", Limit: 20})
	if err != nil {
		t.Fatalf("List(status=active) error = %v", err)
	}
	if len(active) != 0 {
		t.Errorf("deactivated offer still appears in status=active list: %+v", active)
	}
	inactive, _, err := repo.List(ctx, sellerOfferTestSellerID, models.SellerOfferQuery{Search: "SKU-TEST-REPO-1", Status: "inactive", Limit: 20})
	if err != nil {
		t.Fatalf("List(status=inactive) error = %v", err)
	}
	if len(inactive) != 1 {
		t.Errorf("deactivated offer missing from status=inactive list: got %d", len(inactive))
	}
}

// TestSellerOfferRepository_Create_DuplicateSKU_UniqueViolation covers
// Stage 7 §7: SKU must be unique per seller, enforced by the DB's own
// UNIQUE(seller_id, sku) constraint — the repository surfaces this as a
// raw unique-violation error for the service layer to translate.
func TestSellerOfferRepository_Create_DuplicateSKU_UniqueViolation(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOfferRepository(pool)
	ctx := context.Background()

	offerID, err := repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 3, SKU: "SKU-TEST-REPO-DUP", Price: "5000.00", DeliveryDays: 0, Stock: 1,
	})
	if err != nil {
		t.Fatalf("first Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestOffer(t, pool, offerID) })

	_, err = repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 6, SKU: "SKU-TEST-REPO-DUP", Price: "6000.00", DeliveryDays: 0, Stock: 1,
	})
	if err == nil {
		t.Fatal("expected a unique-violation error for a duplicate seller+sku, got nil")
	}
	if !repositories.IsUniqueViolation(err) {
		t.Errorf("Create() error = %v, want a unique-violation error", err)
	}
}

// TestSellerOfferRepository_Update_CrossSellerOwnership covers Stage 7 §8:
// a seller can never update another seller's offer — the ownership-scoped
// WHERE clause makes this indistinguishable from a nonexistent offer.
func TestSellerOfferRepository_Update_CrossSellerOwnership(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOfferRepository(pool)
	ctx := context.Background()

	offerID, err := repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 8, SKU: "SKU-TEST-REPO-OWN", Price: "7000.00", DeliveryDays: 0, Stock: 2,
	})
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	t.Cleanup(func() { deleteTestOffer(t, pool, offerID) })

	const wrongSellerID = int64(4)
	err = repo.Update(ctx, wrongSellerID, offerID, models.UpdateOfferInput{SKU: "HACKED", Price: "1.00", DeliveryDays: 0})
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "OFFER_NOT_FOUND" {
		t.Errorf("cross-seller Update() error = %v, want *models.NotFoundError{OFFER_NOT_FOUND}", err)
	}

	err = repo.UpdateStatus(ctx, wrongSellerID, offerID, false)
	nfErr, ok = err.(*models.NotFoundError)
	if !ok || nfErr.Code != "OFFER_NOT_FOUND" {
		t.Errorf("cross-seller UpdateStatus() error = %v, want *models.NotFoundError{OFFER_NOT_FOUND}", err)
	}

	err = repo.UpdateInventory(ctx, wrongSellerID, offerID, 99)
	nfErr, ok = err.(*models.NotFoundError)
	if !ok || nfErr.Code != "OFFER_NOT_FOUND" {
		t.Errorf("cross-seller UpdateInventory() error = %v, want *models.NotFoundError{OFFER_NOT_FOUND}", err)
	}
}

// TestSellerOfferRepository_Inventory_LowStockCalc covers Stage 7 §10:
// is_low_stock is server-computed against models.LowStockThreshold, never
// left for the frontend to calculate.
func TestSellerOfferRepository_Inventory_LowStockCalc(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOfferRepository(pool)
	ctx := context.Background()

	lowOfferID, err := repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 1, SKU: "SKU-TEST-REPO-LOW", Price: "1000.00", DeliveryDays: 0, Stock: models.LowStockThreshold - 1,
	})
	if err != nil {
		t.Fatalf("Create(low stock) error = %v", err)
	}
	t.Cleanup(func() { deleteTestOffer(t, pool, lowOfferID) })

	healthyOfferID, err := repo.Create(ctx, sellerOfferTestSellerID, models.CreateOfferInput{
		ProductID: 3, SKU: "SKU-TEST-REPO-HEALTHY", Price: "1000.00", DeliveryDays: 0, Stock: models.LowStockThreshold + 10,
	})
	if err != nil {
		t.Fatalf("Create(healthy stock) error = %v", err)
	}
	t.Cleanup(func() { deleteTestOffer(t, pool, healthyOfferID) })

	items, err := repo.ListInventory(ctx, sellerOfferTestSellerID)
	if err != nil {
		t.Fatalf("ListInventory() error = %v", err)
	}
	var lowFound, healthyFound bool
	for _, it := range items {
		if it.OfferID == lowOfferID {
			lowFound = true
			if !it.IsLowStock {
				t.Errorf("offer with stock %d below threshold %d should be low-stock", models.LowStockThreshold-1, models.LowStockThreshold)
			}
		}
		if it.OfferID == healthyOfferID {
			healthyFound = true
			if it.IsLowStock {
				t.Errorf("offer with stock %d above threshold %d should not be low-stock", models.LowStockThreshold+10, models.LowStockThreshold)
			}
		}
	}
	if !lowFound || !healthyFound {
		t.Fatalf("ListInventory() missing test offers: low=%v healthy=%v", lowFound, healthyFound)
	}

	if err := repo.UpdateInventory(ctx, sellerOfferTestSellerID, lowOfferID, 0); err != nil {
		t.Fatalf("UpdateInventory() error = %v", err)
	}
	items, err = repo.ListInventory(ctx, sellerOfferTestSellerID)
	if err != nil {
		t.Fatalf("ListInventory() after update error = %v", err)
	}
	for _, it := range items {
		if it.OfferID == lowOfferID && it.AvailableQuantity != 0 {
			t.Errorf("UpdateInventory(0) did not persist, available_quantity = %d", it.AvailableQuantity)
		}
	}
}
