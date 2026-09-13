package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

func TestSellerRepository_ListActive(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerRepository(pool)

	sellers, err := repo.ListActive(context.Background())
	if err != nil {
		t.Fatalf("ListActive() error = %v", err)
	}
	if len(sellers) < 3 {
		t.Errorf("expected at least 3 seeded sellers, got %d", len(sellers))
	}
	for _, s := range sellers {
		if s.Name == "" || s.Slug == "" {
			t.Errorf("seller %d missing name/slug: %+v", s.ID, s)
		}
	}
}

func TestSellerRepository_GetByID_Found(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerRepository(pool)
	ctx := context.Background()

	all, err := repo.ListActive(ctx)
	if err != nil || len(all) == 0 {
		t.Fatalf("need at least one seeded seller, err=%v", err)
	}

	detail, err := repo.GetByID(ctx, all[0].ID)
	if err != nil {
		t.Fatalf("GetByID(%d) error = %v", all[0].ID, err)
	}
	if detail.Slug != all[0].Slug {
		t.Errorf("GetByID(%d).Slug = %q, want %q", all[0].ID, detail.Slug, all[0].Slug)
	}
	if !detail.IsActive {
		t.Errorf("GetByID(%d) returned an inactive seller from the active list", all[0].ID)
	}
}

func TestSellerRepository_GetByID_NotFound(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerRepository(pool)

	_, err := repo.GetByID(context.Background(), 99999999)
	if err != models.ErrNotFound {
		t.Errorf("GetByID(unknown) error = %v, want models.ErrNotFound", err)
	}
}

// TestSellerRepository_ListProducts_UsesSellerOwnPrice is the key check for
// Stage 3 §13: a seller's product listing must show THEIR OWN offer price,
// not the marketplace-wide cheapest offer (which may belong to someone
// else) — even for a product that has cheaper competing offers.
func TestSellerRepository_ListProducts_UsesSellerOwnPrice(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	sellerRepo := repositories.NewSellerRepository(pool)
	productRepo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	// Find a product with multiple sellers, and the offer that is NOT the
	// globally cheapest one.
	products, _, err := productRepo.List(ctx, models.ProductFilter{Limit: 100})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	var targetProductID int64
	for _, p := range products {
		if p.SellerCount > 1 {
			targetProductID = p.ID
			break
		}
	}
	if targetProductID == 0 {
		t.Fatal("expected a seeded product with multiple sellers")
	}

	offers, err := productRepo.ListOffers(ctx, targetProductID)
	if err != nil || len(offers) < 2 {
		t.Fatalf("ListOffers(%d) error=%v, offers=%d", targetProductID, err, len(offers))
	}
	nonCheapest := offers[len(offers)-1] // most expensive of this product's offers

	result, total, err := sellerRepo.ListProducts(ctx, nonCheapest.SellerID, 100, 0)
	if err != nil {
		t.Fatalf("ListProducts(%d) error = %v", nonCheapest.SellerID, err)
	}
	if total == 0 {
		t.Fatalf("seller %d should have at least one product", nonCheapest.SellerID)
	}

	var found *models.SellerProductItem
	for i := range result {
		if result[i].ProductID == targetProductID {
			found = &result[i]
			break
		}
	}
	if found == nil {
		t.Fatalf("seller %d should list product %d among their products", nonCheapest.SellerID, targetProductID)
	}
	if found.Price != nonCheapest.Price {
		t.Errorf("seller products endpoint returned price %s, want this seller's own offer price %s", found.Price, nonCheapest.Price)
	}
}

func TestSellerRepository_ListProducts_UnknownSellerReturnsEmpty(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerRepository(pool)

	items, total, err := repo.ListProducts(context.Background(), 99999999, 20, 0)
	if err != nil {
		t.Fatalf("ListProducts(unknown) error = %v", err)
	}
	if total != 0 || len(items) != 0 {
		t.Errorf("expected empty result for unknown seller, got total=%d items=%d", total, len(items))
	}
}
