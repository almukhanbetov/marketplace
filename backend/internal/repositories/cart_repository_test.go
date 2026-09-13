package repositories_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// noCartUserID is a seeded user (admin) who never gets a cart/favorites/
// address row from seeds/seed_demo.go — safe for "user has no cart yet"
// assertions.
const noCartUserID = int64(1)

// Offers on product 25 (three distinct sellers, none touched by any demo
// customer's seeded cart) and product 30 (a single low-stock offer) — see
// the comment on demoUserID/safeProductID in favorite_repository_test.go.
const (
	offerA         = int64(49) // product 25, seller 5
	offerB         = int64(50) // product 25, seller 6
	lowStockOffer  = int64(60) // product 30, available_quantity = 8
	lowStockAmount = 8
)

func TestCartRepository_Get_NoCartYet_ReturnsEmpty(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	cart, err := repo.Get(ctx, noCartUserID)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	if cart.ID != nil {
		t.Errorf("expected nil cart ID for a user with no cart, got %v", *cart.ID)
	}
	if len(cart.Items) != 0 || cart.Summary.ItemCount != 0 {
		t.Errorf("expected empty cart, got %+v", cart)
	}
}

func TestCartRepository_AddItem_MultiSeller_SameProduct(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		cart, _ := repo.Get(ctx, demoUserID)
		for _, it := range cart.Items {
			if it.SellerOfferID == offerA || it.SellerOfferID == offerB {
				_, _ = repo.RemoveItem(ctx, demoUserID, it.ID)
			}
		}
	})

	cart, err := repo.AddItem(ctx, demoUserID, offerA, 1)
	if err != nil {
		t.Fatalf("AddItem(offerA) error = %v", err)
	}
	cart, err = repo.AddItem(ctx, demoUserID, offerB, 1)
	if err != nil {
		t.Fatalf("AddItem(offerB) error = %v", err)
	}

	// Stage 5 §47: two offers of the SAME product from different sellers
	// must be two distinct cart items, never collapsed by product_id.
	var lineA, lineB *models.CartItem
	for i := range cart.Items {
		if cart.Items[i].SellerOfferID == offerA {
			lineA = &cart.Items[i]
		}
		if cart.Items[i].SellerOfferID == offerB {
			lineB = &cart.Items[i]
		}
	}
	if lineA == nil || lineB == nil {
		t.Fatalf("expected separate cart items for offerA and offerB, got items=%+v", cart.Items)
	}
	if lineA.ID == lineB.ID {
		t.Errorf("offerA and offerB collapsed into the same cart item id %d", lineA.ID)
	}
	if lineA.Product.ID != lineB.Product.ID {
		t.Errorf("expected both offers to reference the same product, got %d vs %d", lineA.Product.ID, lineB.Product.ID)
	}
}

// TestCartRepository_AddItem_SameOffer_IncrementsQuantity covers Stage 5
// §10: adding an offer already in the cart increases its quantity instead
// of creating a duplicate row.
func TestCartRepository_AddItem_SameOffer_IncrementsQuantity(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		cart, _ := repo.Get(ctx, demoUserID)
		for _, it := range cart.Items {
			if it.SellerOfferID == offerA {
				_, _ = repo.RemoveItem(ctx, demoUserID, it.ID)
			}
		}
	})

	if _, err := repo.AddItem(ctx, demoUserID, offerA, 2); err != nil {
		t.Fatalf("first AddItem() error = %v", err)
	}
	cart, err := repo.AddItem(ctx, demoUserID, offerA, 1)
	if err != nil {
		t.Fatalf("second AddItem() error = %v", err)
	}

	var lines int
	var qty int
	for _, it := range cart.Items {
		if it.SellerOfferID == offerA {
			lines++
			qty = it.Quantity
		}
	}
	if lines != 1 {
		t.Fatalf("expected exactly 1 cart_items row for offerA, got %d", lines)
	}
	if qty != 3 {
		t.Errorf("expected quantity 2+1=3, got %d", qty)
	}
}

// TestCartRepository_AddItem_InsufficientStock covers Stage 5 §48.
func TestCartRepository_AddItem_InsufficientStock(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	_, err := repo.AddItem(ctx, demoUserID, lowStockOffer, lowStockAmount+1)
	var conflictErr *models.ConflictError
	if err == nil {
		t.Fatal("expected an insufficient-stock error, got nil")
	}
	if ce, ok := err.(*models.ConflictError); ok {
		conflictErr = ce
	}
	if conflictErr == nil || conflictErr.Code != "INSUFFICIENT_STOCK" {
		t.Errorf("expected *models.ConflictError{Code: INSUFFICIENT_STOCK}, got %v", err)
	}
}

func TestCartRepository_AddItem_UnknownOffer(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	_, err := repo.AddItem(ctx, demoUserID, 99999999, 1)
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "SELLER_OFFER_NOT_FOUND" {
		t.Errorf("expected *models.NotFoundError{Code: SELLER_OFFER_NOT_FOUND}, got %v", err)
	}
}

// TestCartRepository_AddItem_InactiveOffer covers Stage 5 §9/§25
// (OFFER_UNAVAILABLE). Temporarily deactivates one seeded offer and
// restores it afterwards — this test's own seller_offers row, not shared
// fixture state.
func TestCartRepository_AddItem_InactiveOffer(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	const inactiveOffer = int64(51) // product 25, seller 8 — unused by other Stage 5 tests
	if _, err := pool.Exec(ctx, `UPDATE seller_offers SET is_active = FALSE WHERE id = $1`, inactiveOffer); err != nil {
		t.Fatalf("deactivate offer: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(ctx, `UPDATE seller_offers SET is_active = TRUE WHERE id = $1`, inactiveOffer)
	})

	_, err := repo.AddItem(ctx, demoUserID, inactiveOffer, 1)
	confErr, ok := err.(*models.ConflictError)
	if !ok || confErr.Code != "OFFER_UNAVAILABLE" {
		t.Errorf("expected *models.ConflictError{Code: OFFER_UNAVAILABLE}, got %v", err)
	}
}

// TestCartRepository_ItemOwnership_CrossUserProtected covers Stage 5 §16:
// an item id belonging to one user's cart must be untouchable through
// another user's userId in the URL.
func TestCartRepository_ItemOwnership_CrossUserProtected(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	cart, err := repo.AddItem(ctx, demoUserID, offerA, 1)
	if err != nil {
		t.Fatalf("AddItem() error = %v", err)
	}
	var itemID int64
	for _, it := range cart.Items {
		if it.SellerOfferID == offerA {
			itemID = it.ID
		}
	}
	if itemID == 0 {
		t.Fatal("could not find the just-added cart item")
	}
	t.Cleanup(func() {
		_, _ = repo.RemoveItem(ctx, demoUserID, itemID)
	})

	const otherUserID = int64(11) // nurlan@example.com — a different seeded customer

	if _, err := repo.UpdateItemQuantity(ctx, otherUserID, itemID, 5); err == nil {
		t.Error("expected UpdateItemQuantity() by a different user to fail, got nil error")
	} else if nfErr, ok := err.(*models.NotFoundError); !ok || nfErr.Code != "CART_ITEM_NOT_FOUND" {
		t.Errorf("expected CART_ITEM_NOT_FOUND, got %v", err)
	}

	if _, err := repo.RemoveItem(ctx, otherUserID, itemID); err == nil {
		t.Error("expected RemoveItem() by a different user to fail, got nil error")
	} else if nfErr, ok := err.(*models.NotFoundError); !ok || nfErr.Code != "CART_ITEM_NOT_FOUND" {
		t.Errorf("expected CART_ITEM_NOT_FOUND, got %v", err)
	}

	// The item must still belong to and be reachable by its real owner.
	cart, err = repo.Get(ctx, demoUserID)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	found := false
	for _, it := range cart.Items {
		if it.ID == itemID {
			found = true
		}
	}
	if !found {
		t.Error("item disappeared from its real owner's cart after cross-user attempts")
	}
}

func TestCartRepository_RemoveItem_UnknownItem(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	_, err := repo.RemoveItem(ctx, demoUserID, 99999999)
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "CART_ITEM_NOT_FOUND" {
		t.Errorf("expected CART_ITEM_NOT_FOUND, got %v", err)
	}
}

// TestCartRepository_LineTotal_UsesBackendPrice proves the line total is
// computed from the offer's current DB price, exactly quantity * price,
// using integer-cents arithmetic (Stage 5 §11/§12).
func TestCartRepository_LineTotal_UsesBackendPrice(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewCartRepository(pool)
	ctx := context.Background()

	t.Cleanup(func() {
		cart, _ := repo.Get(ctx, demoUserID)
		for _, it := range cart.Items {
			if it.SellerOfferID == offerA {
				_, _ = repo.RemoveItem(ctx, demoUserID, it.ID)
			}
		}
	})

	var priceStr string
	if err := pool.QueryRow(ctx, `SELECT price::text FROM seller_offers WHERE id = $1`, offerA).Scan(&priceStr); err != nil {
		t.Fatalf("read offer price: %v", err)
	}

	cart, err := repo.AddItem(ctx, demoUserID, offerA, 3)
	if err != nil {
		t.Fatalf("AddItem() error = %v", err)
	}
	for _, it := range cart.Items {
		if it.SellerOfferID != offerA {
			continue
		}
		if string(it.Price) != priceStr {
			t.Errorf("cart item price = %s, want current offer price %s", it.Price, priceStr)
		}
		wantTotal := multiplyDecimalForTest(t, priceStr, 3)
		if string(it.LineTotal) != wantTotal {
			t.Errorf("line_total = %s, want %s (price * 3)", it.LineTotal, wantTotal)
		}
	}
}

// multiplyDecimalForTest mirrors the repository's own integer-cents money
// arithmetic so this test's expectation isn't computed through float64
// (which is exactly the imprecision Stage 1 §18/Stage 5 §11 forbid in the
// production code path this is verifying).
func multiplyDecimalForTest(t *testing.T, price string, qty int) string {
	t.Helper()
	var whole, frac int64
	if _, err := fmt.Sscanf(price, "%d.%d", &whole, &frac); err != nil {
		t.Fatalf("parse price %q: %v", price, err)
	}
	cents := (whole*100 + frac) * int64(qty)
	return fmt.Sprintf("%d.%02d", cents/100, cents%100)
}
