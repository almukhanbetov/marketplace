package handlers_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// uniqueHandlerTestKey mirrors order_service_test.go's uniqueTestKey (a
// different package, so it can't just import that one) — a fresh
// idempotency key per call, since orders are never deleted and a fixed
// key would hit the idempotent-replay fast path on every re-run after the
// first.
func uniqueHandlerTestKey(name string) string {
	return fmt.Sprintf("%s-%d", name, time.Now().UnixNano())
}

// Stage 6 handler tests use a seller-role user (beautylab@nova.kz, id 6)
// as the "customer" placing orders — unlike aigerim/nurlan/saltanat (ids
// 10/11/12), it has no seeded cart/favorites/address at all, so these
// tests build up everything they need through the real API and can never
// collide with Stage 5's or the other Stage 6 packages' (repositories_test/
// services_test) use of the seeded customers' carts — important because
// `go test ./...` runs each package's tests in its own process against the
// same real, shared dev database (see order_service_test.go's comment for
// the full explanation). Stage 9: identity now comes from a real login,
// not a URL id — see orderTestUserEmail.
const orderTestUserEmail = "beautylab@nova.kz"

// Dedicated offers — distinct from every other package's allocation.
const (
	orderTestOfferA = "78" // product 39, seller 8
	orderTestOfferB = "79" // product 40, seller 8
)

// createTestAddress POSTs a fresh address for the given token and
// returns its id as a string, ready to drop into a request body/URL.
func createTestAddress(t *testing.T, router *gin.Engine, token string) string {
	t.Helper()
	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/addresses", token, map[string]any{
		"city": "Алматы", "street": "ул. Тестовая", "house": "1",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("setup: create address = %d, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	return strconv.Itoa(int(data["id"].(float64)))
}

// clearTestCart empties the token owner's cart — every test calls this
// first, since a *previous* test run may have left an order-creating
// test's cart item behind (order creation failing partway leaves the cart
// untouched by design — that's the rollback guarantee — but it does mean
// stale items can accumulate across repeated `go test` invocations without
// this).
func clearTestCart(t *testing.T, router *gin.Engine, token string) {
	t.Helper()
	rec := authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("setup: clear cart = %d, body=%s", rec.Code, rec.Body.String())
	}
}

func addTestCartItem(t *testing.T, router *gin.Engine, token, offerID string, qty int) {
	t.Helper()
	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/cart/items", token, map[string]any{
		"seller_offer_id": mustAtoi(t, offerID), "quantity": qty,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("setup: add cart item = %d, body=%s", rec.Code, rec.Body.String())
	}
}

func mustAtoi(t *testing.T, s string) int {
	t.Helper()
	n, err := strconv.Atoi(s)
	if err != nil {
		t.Fatalf("mustAtoi(%q): %v", s, err)
	}
	return n
}

func TestOrderHandler_Create_Success(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, orderTestUserEmail)
	clearTestCart(t, router, token)
	addressID := createTestAddress(t, router, token)
	addTestCartItem(t, router, token, orderTestOfferA, 1)

	// A fresh key per run — this test adds a brand new cart item every
	// time, so it must exercise a genuinely new order each time too (a
	// fixed key would hit the idempotent-replay fast path, which correctly
	// leaves the cart untouched — it was already empty from the original
	// run — breaking this test's own re-added item instead of proving
	// anything about idempotency; that's TestOrderHandler_
	// DuplicateIdempotencyKey's job).
	rec := doOrderRequestWithIdempotencyKey(router, token, map[string]any{
		"address_id": mustAtoi(t, addressID), "payment_provider": "kaspi_mock",
	}, uniqueHandlerTestKey("handler-create-success-test"))
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST orders = %d, want 201, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	if data["status"] != "paid" {
		t.Errorf("order status = %v, want paid", data["status"])
	}
	payment, _ := data["payment"].(map[string]any)
	if payment == nil || payment["status"] != "paid" {
		t.Errorf("expected a paid payment, got %v", payment)
	}
	if data["order_number"] == "" || data["order_number"] == nil {
		t.Error("expected a non-empty order_number")
	}

	// Cart must now be empty (§33).
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/me/cart", token, nil)
	cartBody := decodeBody(t, rec)
	cartData, _ := cartBody["data"].(map[string]any)
	items, _ := cartData["items"].([]any)
	if len(items) != 0 {
		t.Errorf("expected empty cart after order, got %d items", len(items))
	}
}

func TestOrderHandler_Create_EmptyCart(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, orderTestUserEmail)
	clearTestCart(t, router, token)
	addressID := createTestAddress(t, router, token)
	// No cart items added — cart is guaranteed empty by clearTestCart above.

	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/orders", token, map[string]any{
		"address_id": mustAtoi(t, addressID), "payment_provider": "card",
	})
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("POST orders with empty cart = %d, want 400, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	errObj, _ := body["error"].(map[string]any)
	if errObj["code"] != "CART_EMPTY" {
		t.Errorf("expected error.code=CART_EMPTY, got %v", body["error"])
	}
}

func TestOrderHandler_Create_InvalidAddress(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, orderTestUserEmail)
	clearTestCart(t, router, token)
	addTestCartItem(t, router, token, orderTestOfferA, 1)
	t.Cleanup(func() { authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart", token, nil) })

	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/orders", token, map[string]any{
		"address_id": 99999999, "payment_provider": "card",
	})
	if rec.Code != http.StatusNotFound {
		t.Fatalf("POST orders with unknown address = %d, want 404, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	errObj, _ := body["error"].(map[string]any)
	if errObj["code"] != "ADDRESS_NOT_FOUND" {
		t.Errorf("expected error.code=ADDRESS_NOT_FOUND, got %v", body["error"])
	}
}

// TestOrderHandler_DuplicateIdempotencyKey covers Stage 6 §35/§59: the same
// Idempotency-Key header submitted twice returns the same order, not a
// duplicate.
func TestOrderHandler_DuplicateIdempotencyKey(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, orderTestUserEmail)
	clearTestCart(t, router, token)
	addressID := createTestAddress(t, router, token)
	addTestCartItem(t, router, token, orderTestOfferB, 1)

	req1 := map[string]any{"address_id": mustAtoi(t, addressID), "payment_provider": "card"}
	rec1 := doOrderRequestWithIdempotencyKey(router, token, req1, "handler-dup-key-test")
	if rec1.Code != http.StatusCreated {
		t.Fatalf("first POST orders = %d, want 201, body=%s", rec1.Code, rec1.Body.String())
	}
	firstBody := decodeBody(t, rec1)
	firstData, _ := firstBody["data"].(map[string]any)
	firstID := firstData["id"]

	rec2 := doOrderRequestWithIdempotencyKey(router, token, req1, "handler-dup-key-test")
	if rec2.Code != http.StatusCreated {
		t.Fatalf("replayed POST orders = %d, want 201, body=%s", rec2.Code, rec2.Body.String())
	}
	secondBody := decodeBody(t, rec2)
	secondData, _ := secondBody["data"].(map[string]any)
	if secondData["id"] != firstID {
		t.Errorf("replayed order id = %v, want the same order %v", secondData["id"], firstID)
	}
}

func doOrderRequestWithIdempotencyKey(router *gin.Engine, token string, body map[string]any, key string) *httptest.ResponseRecorder {
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/me/orders", bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Idempotency-Key", key)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestOrderHandler_ListAndGet(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, orderTestUserEmail)
	clearTestCart(t, router, token)
	addressID := createTestAddress(t, router, token)
	addTestCartItem(t, router, token, orderTestOfferA, 1)
	createRec := doOrderRequestWithIdempotencyKey(router, token, map[string]any{"address_id": mustAtoi(t, addressID), "payment_provider": "card"}, "handler-list-get-test")
	if createRec.Code != http.StatusCreated {
		t.Fatalf("setup order = %d, body=%s", createRec.Code, createRec.Body.String())
	}
	created := decodeBody(t, createRec)
	createdData, _ := created["data"].(map[string]any)
	orderID := strconv.Itoa(int(createdData["id"].(float64)))

	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/me/orders", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET orders = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	listBody := decodeBody(t, rec)
	list, _ := listBody["data"].([]any)
	if len(list) == 0 {
		t.Fatal("expected at least 1 order in the list")
	}

	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/me/orders/"+orderID, token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET order detail = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	detailBody := decodeBody(t, rec)
	detailData, _ := detailBody["data"].(map[string]any)
	items, _ := detailData["items"].([]any)
	if len(items) == 0 {
		t.Error("expected at least 1 item in order detail")
	}
	// Customer-facing detail must never expose seller finance (§32).
	if _, has := detailData["commission_total"]; has {
		t.Error("order detail must not expose commission_total to the customer")
	}
	if item, ok := items[0].(map[string]any); ok {
		if _, has := item["commission_amount"]; has {
			t.Error("order item must not expose commission_amount to the customer")
		}
		if _, has := item["seller_amount"]; has {
			t.Error("order item must not expose seller_amount to the customer")
		}
	}

	// Cross-user access (Stage 9 §21/§51): order belongs to
	// beautylab@nova.kz, requested with sportzone@nova.kz's own valid
	// token — must be a 404, never a cross-user leak (§53).
	otherToken := loginAndGetToken(t, router, "sportzone@nova.kz")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/me/orders/"+orderID, otherToken, nil)
	if rec.Code != http.StatusNotFound {
		t.Errorf("cross-user GET order detail = %d, want 404", rec.Code)
	}
}
