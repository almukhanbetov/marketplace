package repositories_test

import (
	"context"
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// findMultiSellerOrder returns the id of a real seeded order with items
// from at least 2 distinct sellers, and the list of those seller ids. Read
// only — this test never mutates data, so it needs no dedicated fixture
// allocation and can't race any other package.
func findMultiSellerOrder(t *testing.T) (int64, []int64) {
	t.Helper()
	pool := testutil.ConnectTestDB(t)
	ctx := context.Background()

	rows, err := pool.Query(ctx, `
		SELECT order_id, array_agg(DISTINCT seller_id ORDER BY seller_id)
		FROM order_items
		GROUP BY order_id
		HAVING COUNT(DISTINCT seller_id) >= 2
		LIMIT 1
	`)
	if err != nil {
		t.Fatalf("find multi-seller order: %v", err)
	}
	defer rows.Close()

	if !rows.Next() {
		t.Skip("no seeded multi-seller order found")
	}
	var orderID int64
	var sellerIDs []int64
	if err := rows.Scan(&orderID, &sellerIDs); err != nil {
		t.Fatalf("scan multi-seller order: %v", err)
	}
	return orderID, sellerIDs
}

// TestSellerOrderRepository_GetDetail_MultiSellerIsolation is the core
// privacy proof for Stage 7 §13/§15/§53: on an order with items from
// multiple sellers, each seller's GetDetail call returns ONLY that
// seller's own lines/amounts — another seller's lines on the same order
// are structurally unreachable, never just filtered client-side.
func TestSellerOrderRepository_GetDetail_MultiSellerIsolation(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOrderRepository(pool)
	ctx := context.Background()

	orderID, sellerIDs := findMultiSellerOrder(t)
	if len(sellerIDs) < 2 {
		t.Fatalf("expected at least 2 distinct sellers, got %v", sellerIDs)
	}

	for _, sellerID := range sellerIDs {
		detail, err := repo.GetDetail(ctx, sellerID, orderID)
		if err != nil {
			t.Fatalf("GetDetail(seller=%d, order=%d) error = %v", sellerID, orderID, err)
		}
		if len(detail.Items) == 0 {
			t.Fatalf("GetDetail(seller=%d) returned zero items despite order_items proving it has some", sellerID)
		}

		var expectedGross string
		if err := pool.QueryRow(ctx, `SELECT SUM(total_price)::text FROM order_items WHERE order_id = $1 AND seller_id = $2`, orderID, sellerID).Scan(&expectedGross); err != nil {
			t.Fatalf("read expected gross for seller %d: %v", sellerID, err)
		}
		if detail.SellerGrossAmount != models.Money(expectedGross) {
			t.Errorf("seller %d gross = %s, want %s", sellerID, detail.SellerGrossAmount, expectedGross)
		}

		// No item on this seller's view may belong to a different seller —
		// verified against the DB directly rather than trusting the
		// repository's own WHERE clause.
		rows, err := pool.Query(ctx, `SELECT sku FROM order_items WHERE order_id = $1 AND seller_id != $2`, orderID, sellerID)
		if err != nil {
			t.Fatalf("read other sellers' skus: %v", err)
		}
		otherSKUs := map[string]bool{}
		for rows.Next() {
			var sku string
			rows.Scan(&sku)
			otherSKUs[sku] = true
		}
		rows.Close()
		for _, item := range detail.Items {
			if otherSKUs[item.SKU] {
				t.Errorf("seller %d's order detail leaked another seller's sku %q", sellerID, item.SKU)
			}
		}
	}

	// A seller with no items at all on this order must get a clean
	// not-found, not an empty-but-200 response.
	var unrelatedSellerID int64
	if err := pool.QueryRow(ctx, `SELECT id FROM sellers WHERE id != ALL($1) LIMIT 1`, sellerIDs).Scan(&unrelatedSellerID); err != nil {
		t.Fatalf("find unrelated seller: %v", err)
	}
	_, err := repo.GetDetail(ctx, unrelatedSellerID, orderID)
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "ORDER_NOT_FOUND" {
		t.Errorf("GetDetail(unrelated seller=%d, order=%d) error = %v, want *models.NotFoundError{ORDER_NOT_FOUND}", unrelatedSellerID, orderID, err)
	}
}

// TestSellerOrderRepository_List_OnlyOwnOrders covers Stage 7 §13: List
// must only return orders containing at least one item for this seller,
// and every summary's amounts must derive from this seller's own lines.
func TestSellerOrderRepository_List_OnlyOwnOrders(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewSellerOrderRepository(pool)
	ctx := context.Background()

	orderID, sellerIDs := findMultiSellerOrder(t)
	sellerID := sellerIDs[0]

	items, total, err := repo.List(ctx, sellerID, 100, 0)
	if err != nil {
		t.Fatalf("List(seller=%d) error = %v", sellerID, err)
	}
	if total == 0 || len(items) == 0 {
		t.Fatalf("expected at least 1 order for seller %d", sellerID)
	}

	var found *models.SellerOrderSummary
	for i := range items {
		if items[i].OrderID == orderID {
			found = &items[i]
			break
		}
	}
	if found == nil {
		t.Fatalf("List(seller=%d) missing known order %d", sellerID, orderID)
	}

	var expectedNet string
	if err := pool.QueryRow(ctx, `SELECT SUM(seller_amount)::text FROM order_items WHERE order_id = $1 AND seller_id = $2`, orderID, sellerID).Scan(&expectedNet); err != nil {
		t.Fatalf("read expected net: %v", err)
	}
	if found.SellerNetAmount != models.Money(expectedNet) {
		t.Errorf("List() seller_net_amount = %s, want %s", found.SellerNetAmount, expectedNet)
	}
}
