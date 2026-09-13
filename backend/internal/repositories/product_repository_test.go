package repositories_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

func TestProductRepository_List_Basic(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	items, total, err := repo.List(context.Background(), models.ProductFilter{Limit: 20, Offset: 0})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if total < 30 {
		t.Errorf("expected at least 30 seeded products, got total=%d", total)
	}
	if len(items) != 20 {
		t.Errorf("expected 20 items for limit=20, got %d", len(items))
	}
	for _, p := range items {
		if p.Price == "" {
			t.Errorf("product %d has empty price", p.ID)
		}
		if p.SellerCount < 1 {
			t.Errorf("product %d returned by List() must have at least one valid offer, got seller_count=%d", p.ID, p.SellerCount)
		}
	}
}

func TestProductRepository_List_FilteredByCategory(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	items, total, err := repo.List(context.Background(), models.ProductFilter{
		CategorySlug: "electronics", Limit: 50,
	})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if total == 0 {
		t.Fatal("expected electronics category to have seeded products")
	}
	for _, p := range items {
		if p.Category.Slug != "electronics" {
			t.Errorf("filtered by category=electronics but got product %d in category %q", p.ID, p.Category.Slug)
		}
	}
}

func TestProductRepository_List_SearchIsCaseInsensitive(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	lower, _, err := repo.List(ctx, models.ProductFilter{Search: "iphone", Limit: 20})
	if err != nil {
		t.Fatalf("List(search=iphone) error = %v", err)
	}
	upper, _, err := repo.List(ctx, models.ProductFilter{Search: "IPHONE", Limit: 20})
	if err != nil {
		t.Fatalf("List(search=IPHONE) error = %v", err)
	}
	if len(lower) == 0 {
		t.Fatal("expected at least one iPhone product in seed data")
	}
	if len(lower) != len(upper) {
		t.Errorf("search should be case-insensitive: %d results for lowercase, %d for uppercase", len(lower), len(upper))
	}
}

func TestProductRepository_List_PriceRangeFilter(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	items, _, err := repo.List(context.Background(), models.ProductFilter{
		MinPrice: "100000.00", MaxPrice: "500000.00", Limit: 100,
	})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	if len(items) == 0 {
		t.Fatal("expected at least one product in the 100000-500000 range")
	}
	for _, p := range items {
		price := parseMoneyForTest(t, string(p.Price))
		if price < 100000 || price > 500000 {
			t.Errorf("product %d price %s is outside the requested min/max_price range", p.ID, p.Price)
		}
	}
}

func TestProductRepository_List_Pagination_CountCorrectness(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	page1, total1, err := repo.List(ctx, models.ProductFilter{Limit: 5, Offset: 0})
	if err != nil {
		t.Fatalf("List(page1) error = %v", err)
	}
	page2, total2, err := repo.List(ctx, models.ProductFilter{Limit: 5, Offset: 5})
	if err != nil {
		t.Fatalf("List(page2) error = %v", err)
	}

	if total1 != total2 {
		t.Errorf("total should be identical across pages of the same filter: %d vs %d", total1, total2)
	}
	if len(page1) != 5 || len(page2) != 5 {
		t.Fatalf("expected 5 items per page (total=%d), got %d and %d", total1, len(page1), len(page2))
	}

	seen := map[int64]bool{}
	for _, p := range page1 {
		seen[p.ID] = true
	}
	for _, p := range page2 {
		if seen[p.ID] {
			t.Errorf("product %d appeared on both page 1 (offset=0) and page 2 (offset=5) — pagination overlap", p.ID)
		}
	}
}

func TestProductRepository_List_SortPriceAsc(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	items, _, err := repo.List(context.Background(), models.ProductFilter{Sort: models.SortPriceAsc, Limit: 50})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}
	for i := 1; i < len(items); i++ {
		prev := parseMoneyForTest(t, string(items[i-1].Price))
		cur := parseMoneyForTest(t, string(items[i].Price))
		if cur < prev {
			t.Fatalf("sort=price_asc not ascending at index %d: %s then %s", i, items[i-1].Price, items[i].Price)
		}
	}
}

func TestProductRepository_List_EmptyFilterReturnsEmptyNotError(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	items, total, err := repo.List(context.Background(), models.ProductFilter{
		Search: "definitely-does-not-exist-zzz", Limit: 20,
	})
	if err != nil {
		t.Fatalf("List() with no matches should not error, got %v", err)
	}
	if total != 0 || len(items) != 0 {
		t.Errorf("expected empty result, got total=%d items=%d", total, len(items))
	}
}

func TestProductRepository_GetByID(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	items, _, err := repo.List(ctx, models.ProductFilter{Limit: 1})
	if err != nil || len(items) == 0 {
		t.Fatalf("need at least one seeded product to run this test, err=%v", err)
	}
	id := items[0].ID

	detail, err := repo.GetByID(ctx, id)
	if err != nil {
		t.Fatalf("GetByID(%d) error = %v", id, err)
	}
	if detail.Slug != items[0].Slug {
		t.Errorf("GetByID(%d).Slug = %q, want %q", id, detail.Slug, items[0].Slug)
	}
	if detail.BestOffer == nil {
		t.Errorf("GetByID(%d).BestOffer is nil for a product returned by List (which requires a valid offer)", id)
	}
	if len(detail.Images) == 0 {
		t.Errorf("GetByID(%d) expected at least one seeded image", id)
	}
}

func TestProductRepository_GetByID_NotFound(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	_, err := repo.GetByID(context.Background(), 99999999)
	if err != models.ErrNotFound {
		t.Errorf("GetByID(unknown) error = %v, want models.ErrNotFound", err)
	}
}

// TestProductRepository_MultiSellerProduct is the key marketplace proof:
// find a product with more than one seller and confirm ListOffers actually
// returns offers from more than one distinct seller, sorted cheapest first.
func TestProductRepository_MultiSellerProduct(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)
	ctx := context.Background()

	items, _, err := repo.List(ctx, models.ProductFilter{Limit: 100})
	if err != nil {
		t.Fatalf("List() error = %v", err)
	}

	var multiSellerID int64
	for _, p := range items {
		if p.SellerCount > 1 {
			multiSellerID = p.ID
			break
		}
	}
	if multiSellerID == 0 {
		t.Fatal("expected at least one seeded product with more than one seller — marketplace model is not demonstrated")
	}

	offers, err := repo.ListOffers(ctx, multiSellerID)
	if err != nil {
		t.Fatalf("ListOffers(%d) error = %v", multiSellerID, err)
	}

	distinctSellers := map[int64]bool{}
	for _, o := range offers {
		distinctSellers[o.SellerID] = true
	}
	if len(distinctSellers) < 2 {
		t.Fatalf("product %d: expected offers from >= 2 distinct sellers, got %d", multiSellerID, len(distinctSellers))
	}

	for i := 1; i < len(offers); i++ {
		prev := parseMoneyForTest(t, string(offers[i-1].Price))
		cur := parseMoneyForTest(t, string(offers[i].Price))
		if cur < prev {
			t.Fatalf("offers not sorted price-ascending at index %d", i)
		}
	}
}

func TestProductRepository_ListOffers_UnknownProductReturnsEmpty(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewProductRepository(pool)

	offers, err := repo.ListOffers(context.Background(), 99999999)
	if err != nil {
		t.Fatalf("ListOffers(unknown) error = %v", err)
	}
	if len(offers) != 0 {
		t.Errorf("expected zero offers for unknown product, got %d", len(offers))
	}
}

func parseMoneyForTest(t *testing.T, s string) float64 {
	t.Helper()
	var whole, frac int
	n, err := fmt.Sscanf(s, "%d.%d", &whole, &frac)
	if err != nil || n != 2 {
		t.Fatalf("could not parse money value %q: %v", s, err)
	}
	return float64(whole) + float64(frac)/100
}
