package services_test

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// Stage 6 order tests deliberately avoid the seeded customers (10/11/12)
// that Stage 5's repositories_test/services_test/handlers_test AND Stage
// 6's own handlers_test already exercise: `go test ./...` runs every
// package's tests as a separate process, in parallel, against the same
// real dev database, and a whole-cart operation (isolateCart below reads
// the entire cart, removes every line, and restores it at the end) racing
// against another package's concurrent per-offer cart mutation on the same
// user produced exactly the kind of "cart item N not found" flake you'd
// expect. Seller-role users (7/8/9) have no seeded cart/favorites/address
// at all and no other package ever touches them, so they're safe to use
// here without any inter-package coordination. Offers are also dedicated
// to this package (product 37/38), distinct from every other package's
// allocation, for the same reason.
const (
	svcOrderUserID = int64(7)  // sportzone@nova.kz — dedicated to this package
	svcOrderOfferA = int64(73) // product 37, seller 6
	svcOrderOfferB = int64(62) // product 31, seller 3 — a *different* seller
	// than offerA's (6) and distinct from every seller any other package's
	// Stage 6 tests credit (handlers_test's offers all belong to seller 8;
	// the concurrency test below uses seller 7) — two packages crediting
	// the same seller_balances row concurrently broke this test's exact
	// before/after delta assertion even though the *offers* themselves
	// never collided.
)

func newOrderTestServices(pool *pgxpool.Pool) (*services.OrderService, *services.CartService, *services.AddressService) {
	userRepo := repositories.NewUserRepository(pool)
	orderService := services.NewOrderService(repositories.NewOrderRepository(pool), userRepo)
	cartService := services.NewCartService(repositories.NewCartRepository(pool), userRepo)
	addressService := services.NewAddressService(repositories.NewAddressRepository(pool), userRepo)
	return orderService, cartService, addressService
}

// ensureAddress returns an existing address id for userID, creating one if
// it has none yet — idempotent across repeated test runs.
func ensureAddress(t *testing.T, ctx context.Context, addressService *services.AddressService, userID int64) int64 {
	t.Helper()
	existing, err := addressService.List(ctx, userID)
	if err != nil {
		t.Fatalf("List addresses for user %d: %v", userID, err)
	}
	if len(existing) > 0 {
		return existing[0].ID
	}
	addr, err := addressService.Create(ctx, userID, models.AddressInput{
		City: "Алматы", Street: "ул. Тестовая", House: "1", IsDefault: true,
	})
	if err != nil {
		t.Fatalf("Create address for user %d: %v", userID, err)
	}
	return addr.ID
}

// clearCart empties userID's cart unconditionally — the dedicated fixture
// users here have nothing worth preserving, so tests just start from a
// known-empty state rather than bothering to save/restore.
func clearCart(t *testing.T, ctx context.Context, cartService *services.CartService, userID int64) {
	t.Helper()
	if _, err := cartService.Clear(ctx, userID); err != nil {
		t.Fatalf("Clear cart for user %d: %v", userID, err)
	}
}

// uniqueTestKey returns a fresh idempotency key each call — order-creating
// tests must never reuse a fixed string across separate `go test`
// invocations: orders are never deleted, so a fixed key would hit the
// idempotent-replay fast path and silently return a stale order from a
// previous run instead of exercising this run's logic.
func uniqueTestKey(name string) string {
	return fmt.Sprintf("%s-%d", name, time.Now().UnixNano())
}

func restoreInventory(t *testing.T, pool *pgxpool.Pool, offerID int64, delta int) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `UPDATE inventory SET available_quantity = available_quantity + $1 WHERE seller_offer_id = $2`, delta, offerID)
	if err != nil {
		t.Errorf("restore inventory for offer %d: %v", offerID, err)
	}
}

func sellerIDForOffer(t *testing.T, pool *pgxpool.Pool, offerID int64) int64 {
	t.Helper()
	var sellerID int64
	if err := pool.QueryRow(context.Background(), `SELECT seller_id FROM seller_offers WHERE id = $1`, offerID).Scan(&sellerID); err != nil {
		t.Fatalf("look up seller for offer %d: %v", offerID, err)
	}
	return sellerID
}

func TestOrderService_EmptyCart(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()

	clearCart(t, ctx, cartService, svcOrderUserID)
	addressID := ensureAddress(t, ctx, addressService, svcOrderUserID)

	_, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("svc-empty-cart-test"),
	})
	if err == nil {
		t.Fatal("expected an error for an empty cart, got nil")
	}
	ve, ok := err.(*models.ValidationError)
	if !ok || ve.Code != "CART_EMPTY" {
		t.Errorf("expected VALIDATION_ERROR CART_EMPTY, got %v", err)
	}
}

func TestOrderService_InvalidAddress(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, _ := newOrderTestServices(pool)
	ctx := context.Background()

	clearCart(t, ctx, cartService, svcOrderUserID)
	if _, err := cartService.AddItem(ctx, svcOrderUserID, svcOrderOfferA, 1); err != nil {
		t.Fatalf("AddItem() error = %v", err)
	}
	t.Cleanup(func() { clearCart(t, context.Background(), cartService, svcOrderUserID) })

	_, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: 99999999, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("svc-invalid-address-test"),
	})
	if err == nil {
		t.Fatal("expected an error for an unknown address, got nil")
	}
	nfErr, ok := err.(*models.NotFoundError)
	if !ok || nfErr.Code != "ADDRESS_NOT_FOUND" {
		t.Errorf("expected ADDRESS_NOT_FOUND, got %v", err)
	}

	// The cart must be untouched — the address check happens before any
	// inventory mutation.
	cart, err := cartService.Get(ctx, svcOrderUserID)
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}
	found := false
	for _, it := range cart.Items {
		if it.SellerOfferID == svcOrderOfferA {
			found = true
		}
	}
	if !found {
		t.Error("cart item for offerA disappeared after a failed order attempt")
	}
}

func TestOrderService_InvalidPaymentProvider(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()

	clearCart(t, ctx, cartService, svcOrderUserID)
	addressID := ensureAddress(t, ctx, addressService, svcOrderUserID)

	_, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: "bitcoin", IdempotencyKey: uniqueTestKey("svc-bad-provider-test"),
	})
	if _, ok := err.(*models.ValidationError); !ok {
		t.Errorf("expected *models.ValidationError for an invalid provider, got %v", err)
	}
}

// TestOrderService_SingleSellerOrder_Accounting is the core accounting
// proof (Stage 6 §48/§50): commission + seller_amount == total_price
// exactly, subtotal/commission_total match the sums, seller pending
// balance increases by exactly the seller_amount, available_amount is
// untouched, inventory decrements by exactly the ordered quantity, and the
// cart is cleared.
func TestOrderService_SingleSellerOrder_Accounting(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()
	sellerID := sellerIDForOffer(t, pool, svcOrderOfferA)

	clearCart(t, ctx, cartService, svcOrderUserID)
	addressID := ensureAddress(t, ctx, addressService, svcOrderUserID)
	if _, err := cartService.AddItem(ctx, svcOrderUserID, svcOrderOfferA, 2); err != nil {
		t.Fatalf("AddItem() error = %v", err)
	}

	var availableBefore int
	var pendingBefore, availableAmountBefore string
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, svcOrderOfferA).Scan(&availableBefore); err != nil {
		t.Fatalf("read inventory before: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT pending_amount::text, available_amount::text FROM seller_balances WHERE seller_id = $1`, sellerID).Scan(&pendingBefore, &availableAmountBefore); err != nil {
		t.Fatalf("read seller balance before: %v", err)
	}

	order, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("svc-single-seller-accounting-test"),
	})
	if err != nil {
		t.Fatalf("CreateOrder() error = %v", err)
	}
	t.Cleanup(func() {
		restoreInventory(t, pool, svcOrderOfferA, 2)
	})

	if order.Status != models.OrderStatusPaid {
		t.Errorf("order.status = %q, want paid", order.Status)
	}
	if order.Payment == nil || order.Payment.Status != "paid" {
		t.Errorf("expected a paid payment, got %+v", order.Payment)
	}
	if len(order.Items) != 1 {
		t.Fatalf("expected 1 order item, got %d", len(order.Items))
	}

	// Cart must be empty after a successful order (§33).
	cart, err := cartService.Get(ctx, svcOrderUserID)
	if err != nil {
		t.Fatalf("Get cart after order: %v", err)
	}
	if len(cart.Items) != 0 {
		t.Errorf("expected empty cart after order, got %d items", len(cart.Items))
	}

	var availableAfter int
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, svcOrderOfferA).Scan(&availableAfter); err != nil {
		t.Fatalf("read inventory after: %v", err)
	}
	if availableBefore-availableAfter != 2 {
		t.Errorf("inventory decreased by %d, want 2", availableBefore-availableAfter)
	}

	var pendingAfter, availableAmountAfter string
	if err := pool.QueryRow(ctx, `SELECT pending_amount::text, available_amount::text FROM seller_balances WHERE seller_id = $1`, sellerID).Scan(&pendingAfter, &availableAmountAfter); err != nil {
		t.Fatalf("read seller balance after: %v", err)
	}
	t.Cleanup(func() {
		// Undo exactly the credit this order made, using the DB's own
		// arithmetic so cents can't drift between test runs.
		_, _ = pool.Exec(context.Background(), `UPDATE seller_balances SET pending_amount = $1 WHERE seller_id = $2`, pendingBefore, sellerID)
	})
	if availableAmountAfter != availableAmountBefore {
		t.Errorf("available_amount changed from %s to %s — Stage 6 §22 requires it stay untouched", availableAmountBefore, availableAmountAfter)
	}

	var commissionAmount, sellerAmount, totalPrice string
	if err := pool.QueryRow(ctx, `SELECT commission_amount::text, seller_amount::text, total_price::text FROM order_items WHERE order_id = $1`, order.ID).Scan(&commissionAmount, &sellerAmount, &totalPrice); err != nil {
		t.Fatalf("read order_item accounting: %v", err)
	}
	sumCents := moneyToCentsForTest(t, commissionAmount) + moneyToCentsForTest(t, sellerAmount)
	if sumCents != moneyToCentsForTest(t, totalPrice) {
		t.Errorf("commission_amount(%s) + seller_amount(%s) = %d cents, want total_price(%s) = %d cents",
			commissionAmount, sellerAmount, sumCents, totalPrice, moneyToCentsForTest(t, totalPrice))
	}
}

// TestOrderService_MultiSellerOrder_Finance covers Stage 6 §23/§24/§47/§62:
// one order, items from two different sellers, each seller's pending
// balance credited independently and exactly.
func TestOrderService_MultiSellerOrder_Finance(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()

	sellerA := sellerIDForOffer(t, pool, svcOrderOfferA)
	sellerB := sellerIDForOffer(t, pool, svcOrderOfferB)
	if sellerA == sellerB {
		t.Fatalf("test fixtures svcOrderOfferA/B must belong to different sellers, both resolved to %d", sellerA)
	}

	clearCart(t, ctx, cartService, svcOrderUserID)
	addressID := ensureAddress(t, ctx, addressService, svcOrderUserID)
	if _, err := cartService.AddItem(ctx, svcOrderUserID, svcOrderOfferA, 1); err != nil {
		t.Fatalf("AddItem(A) error = %v", err)
	}
	if _, err := cartService.AddItem(ctx, svcOrderUserID, svcOrderOfferB, 1); err != nil {
		t.Fatalf("AddItem(B) error = %v", err)
	}

	var pendingABefore, pendingBBefore string
	pool.QueryRow(ctx, `SELECT pending_amount::text FROM seller_balances WHERE seller_id = $1`, sellerA).Scan(&pendingABefore)
	pool.QueryRow(ctx, `SELECT pending_amount::text FROM seller_balances WHERE seller_id = $1`, sellerB).Scan(&pendingBBefore)

	order, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("svc-multi-seller-test"),
	})
	if err != nil {
		t.Fatalf("CreateOrder() error = %v", err)
	}
	t.Cleanup(func() {
		restoreInventory(t, pool, svcOrderOfferA, 1)
		restoreInventory(t, pool, svcOrderOfferB, 1)
		_, _ = pool.Exec(context.Background(), `UPDATE seller_balances SET pending_amount = $1 WHERE seller_id = $2`, pendingABefore, sellerA)
		_, _ = pool.Exec(context.Background(), `UPDATE seller_balances SET pending_amount = $1 WHERE seller_id = $2`, pendingBBefore, sellerB)
	})

	if len(order.Items) != 2 {
		t.Fatalf("expected 2 order items (one per seller), got %d", len(order.Items))
	}

	distinctSellers := map[string]bool{}
	for _, it := range order.Items {
		distinctSellers[it.SellerName] = true
	}
	if len(distinctSellers) != 2 {
		t.Errorf("expected 2 distinct seller names on the order items, got %v", distinctSellers)
	}

	var sellerAmountA, sellerAmountB string
	pool.QueryRow(ctx, `SELECT seller_amount::text FROM order_items WHERE order_id = $1 AND seller_id = $2`, order.ID, sellerA).Scan(&sellerAmountA)
	pool.QueryRow(ctx, `SELECT seller_amount::text FROM order_items WHERE order_id = $1 AND seller_id = $2`, order.ID, sellerB).Scan(&sellerAmountB)

	var pendingAAfter, pendingBAfter string
	pool.QueryRow(ctx, `SELECT pending_amount::text FROM seller_balances WHERE seller_id = $1`, sellerA).Scan(&pendingAAfter)
	pool.QueryRow(ctx, `SELECT pending_amount::text FROM seller_balances WHERE seller_id = $1`, sellerB).Scan(&pendingBAfter)

	if moneyToCentsForTest(t, pendingAAfter)-moneyToCentsForTest(t, pendingABefore) != moneyToCentsForTest(t, sellerAmountA) {
		t.Errorf("seller %d pending balance did not increase by exactly its seller_amount %s", sellerA, sellerAmountA)
	}
	if moneyToCentsForTest(t, pendingBAfter)-moneyToCentsForTest(t, pendingBBefore) != moneyToCentsForTest(t, sellerAmountB) {
		t.Errorf("seller %d pending balance did not increase by exactly its seller_amount %s", sellerB, sellerAmountB)
	}

	// Order-level commission_total must equal the sum of the two items'
	// commission_amount (§50).
	var commissionTotal string
	pool.QueryRow(ctx, `SELECT commission_total::text FROM orders WHERE id = $1`, order.ID).Scan(&commissionTotal)
	var sumCommissions int64
	rows, _ := pool.Query(ctx, `SELECT commission_amount::text FROM order_items WHERE order_id = $1`, order.ID)
	for rows.Next() {
		var c string
		rows.Scan(&c)
		sumCommissions += moneyToCentsForTest(t, c)
	}
	rows.Close()
	if moneyToCentsForTest(t, commissionTotal) != sumCommissions {
		t.Errorf("orders.commission_total = %s, want sum of order_items.commission_amount = %d cents", commissionTotal, sumCommissions)
	}
}

// TestOrderService_IdempotentReplay covers Stage 6 §35/§36/§65: the same
// idempotency key submitted twice must produce exactly one order and one
// inventory decrement, not two.
func TestOrderService_IdempotentReplay(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()

	clearCart(t, ctx, cartService, svcOrderUserID)
	addressID := ensureAddress(t, ctx, addressService, svcOrderUserID)
	if _, err := cartService.AddItem(ctx, svcOrderUserID, svcOrderOfferA, 1); err != nil {
		t.Fatalf("AddItem() error = %v", err)
	}

	var availableBefore int
	pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, svcOrderOfferA).Scan(&availableBefore)

	key := uniqueTestKey("svc-idempotent-replay-test")
	first, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("first CreateOrder() error = %v", err)
	}
	t.Cleanup(func() {
		restoreInventory(t, pool, svcOrderOfferA, 1)
		sellerID := sellerIDForOffer(t, pool, svcOrderOfferA)
		var sellerAmount string
		pool.QueryRow(context.Background(), `SELECT seller_amount::text FROM order_items WHERE order_id = $1`, first.ID).Scan(&sellerAmount)
		if sellerAmount != "" {
			_, _ = pool.Exec(context.Background(), `UPDATE seller_balances SET pending_amount = pending_amount - $1 WHERE seller_id = $2`, sellerAmount, sellerID)
		}
	})

	// Cart is now empty — a real double-click would hit this exact state.
	second, err := orderService.CreateOrder(ctx, svcOrderUserID, models.CreateOrderInput{
		AddressID: addressID, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: key,
	})
	if err != nil {
		t.Fatalf("second (replayed) CreateOrder() error = %v", err)
	}
	if second.ID != first.ID {
		t.Errorf("replayed order id = %d, want the same order %d", second.ID, first.ID)
	}

	var orderCount int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM orders WHERE idempotency_key = $1`, key).Scan(&orderCount)
	if orderCount != 1 {
		t.Errorf("expected exactly 1 order for idempotency key %q, got %d", key, orderCount)
	}

	var availableAfter int
	pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, svcOrderOfferA).Scan(&availableAfter)
	if availableBefore-availableAfter != 1 {
		t.Errorf("inventory decreased by %d across two replayed submissions, want exactly 1", availableBefore-availableAfter)
	}
}

// TestOrderService_ConcurrentCheckout_NoOverselling is the critical
// concurrency proof (Stage 6 §16/§64): with exactly one unit of stock,
// two different users attempt to buy it at the same instant. Exactly one
// order must succeed; the other must fail with INSUFFICIENT_STOCK; final
// inventory must be 0, never negative.
func TestOrderService_ConcurrentCheckout_NoOverselling(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	orderService, cartService, addressService := newOrderTestServices(pool)
	ctx := context.Background()

	const (
		buyerA        = int64(8)  // autoplus@nova.kz — dedicated to this test
		buyerB        = int64(9)  // kidsworld@nova.kz — dedicated to this test
		lastUnitOffer = int64(66) // product 33, seller 7 — dedicated to this test
	)

	var originalStock int
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, lastUnitOffer).Scan(&originalStock); err != nil {
		t.Fatalf("read original stock: %v", err)
	}
	if _, err := pool.Exec(ctx, `UPDATE inventory SET available_quantity = 1 WHERE seller_offer_id = $1`, lastUnitOffer); err != nil {
		t.Fatalf("set stock to 1: %v", err)
	}
	t.Cleanup(func() {
		_, _ = pool.Exec(context.Background(), `UPDATE inventory SET available_quantity = $1 WHERE seller_offer_id = $2`, originalStock, lastUnitOffer)
	})

	clearCart(t, ctx, cartService, buyerA)
	clearCart(t, ctx, cartService, buyerB)
	addressA := ensureAddress(t, ctx, addressService, buyerA)
	addressB := ensureAddress(t, ctx, addressService, buyerB)
	t.Cleanup(func() {
		clearCart(t, context.Background(), cartService, buyerA)
		clearCart(t, context.Background(), cartService, buyerB)
	})
	if _, err := cartService.AddItem(ctx, buyerA, lastUnitOffer, 1); err != nil {
		t.Fatalf("AddItem(buyerA) error = %v", err)
	}
	if _, err := cartService.AddItem(ctx, buyerB, lastUnitOffer, 1); err != nil {
		t.Fatalf("AddItem(buyerB) error = %v", err)
	}

	var wg sync.WaitGroup
	results := make([]error, 2)
	orders := make([]*models.OrderDetail, 2)
	wg.Add(2)
	go func() {
		defer wg.Done()
		orders[0], results[0] = orderService.CreateOrder(ctx, buyerA, models.CreateOrderInput{
			AddressID: addressA, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("concurrent-a"),
		})
	}()
	go func() {
		defer wg.Done()
		orders[1], results[1] = orderService.CreateOrder(ctx, buyerB, models.CreateOrderInput{
			AddressID: addressB, PaymentProvider: models.PaymentProviderCard, IdempotencyKey: uniqueTestKey("concurrent-b"),
		})
	}()
	wg.Wait()

	successes := 0
	insufficientStockFailures := 0
	for i, err := range results {
		if err == nil {
			successes++
			orderID := orders[i].ID
			t.Cleanup(func() {
				sellerID := sellerIDForOffer(t, pool, lastUnitOffer)
				var sellerAmount string
				pool.QueryRow(context.Background(), `SELECT seller_amount::text FROM order_items WHERE order_id = $1`, orderID).Scan(&sellerAmount)
				if sellerAmount != "" {
					_, _ = pool.Exec(context.Background(), `UPDATE seller_balances SET pending_amount = pending_amount - $1 WHERE seller_id = $2`, sellerAmount, sellerID)
				}
			})
		} else if ce, ok := err.(*models.ConflictError); ok && ce.Code == "INSUFFICIENT_STOCK" {
			insufficientStockFailures++
		} else {
			t.Errorf("unexpected error from concurrent CreateOrder: %v", err)
		}
	}

	if successes != 1 {
		t.Errorf("expected exactly 1 successful order, got %d", successes)
	}
	if insufficientStockFailures != 1 {
		t.Errorf("expected exactly 1 INSUFFICIENT_STOCK failure, got %d", insufficientStockFailures)
	}

	var finalStock int
	if err := pool.QueryRow(ctx, `SELECT available_quantity FROM inventory WHERE seller_offer_id = $1`, lastUnitOffer).Scan(&finalStock); err != nil {
		t.Fatalf("read final stock: %v", err)
	}
	if finalStock != 0 {
		t.Errorf("final available_quantity = %d, want exactly 0 (no overselling, no under-counting)", finalStock)
	}
	if finalStock < 0 {
		t.Fatal("inventory went negative — overselling occurred")
	}
}

// moneyToCentsForTest parses via strings.Cut/strconv rather than
// fmt.Sscanf("%d.%d", ...), which silently drops the leading zero of a
// fractional part like ".05" (parsing it as 5, not 50) — exact accounting
// assertions can't tolerate that.
func moneyToCentsForTest(t *testing.T, s string) int64 {
	t.Helper()
	if s == "" {
		return 0
	}
	whole, frac, _ := strings.Cut(s, ".")
	w, err := strconv.ParseInt(whole, 10, 64)
	if err != nil {
		t.Fatalf("parse money %q: %v", s, err)
	}
	frac = (frac + "00")[:2]
	f, err := strconv.ParseInt(frac, 10, 64)
	if err != nil {
		t.Fatalf("parse money %q: %v", s, err)
	}
	return w*100 + f
}
