package handlers_test

import (
	"net/http"
	"strconv"
	"testing"
)

// Stage 5 handler tests reuse the real router (same pattern as
// TestProductsEndpoint etc. above) and the seeded demo customer
// aigerim@example.com (user id 10). Product 28's offers are dedicated to
// this package — distinct from the ids internal/repositories_test and
// internal/services_test use — because `go test ./...` runs each
// package's tests in a separate process against the same real dev
// database, and different packages' tests were otherwise found to race on
// a shared offer/cart row (see Stage 5 report). Stage 9: every private
// route is now under /api/v1/me/... and requires a real access token —
// see loginAndGetToken/authedJSONRequest in testrouter_test.go.
const (
	hDemoUserEmail = "aigerim@example.com"
	hOfferA        = 55
	hOfferB        = 56
	hLowStockOffer = 63 // product 31, available_quantity = 7
)

func TestFavoritesEndpoint_ListAddDuplicateRemove(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, hDemoUserEmail)

	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/me/favorites", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET favorites = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodPost, "/api/v1/me/favorites/25", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST favorites/25 = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	rec = authedJSONRequest(router, http.MethodPost, "/api/v1/me/favorites/25", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("duplicate POST favorites/25 = %d, want 200 (idempotent), body=%s", rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodDelete, "/api/v1/me/favorites/25", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE favorites/25 = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	rec = authedJSONRequest(router, http.MethodDelete, "/api/v1/me/favorites/25", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("repeat DELETE favorites/25 = %d, want 200 (idempotent), body=%s", rec.Code, rec.Body.String())
	}
}

// TestFavoritesEndpoint_Anonymous_401 covers Stage 9 §21/§49: with no
// caller-supplied user id left in the URL at all, the only way to reach
// this data used to be "guess a user id" — now there is nothing to guess;
// the sole gate is a valid access token.
func TestFavoritesEndpoint_Anonymous_401(t *testing.T) {
	router := newFullTestRouter(t)
	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/me/favorites", "", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("GET /me/favorites with no token = %d, want 401", rec.Code)
	}
	body := decodeBody(t, rec)
	errObj, _ := body["error"].(map[string]any)
	if errObj["code"] != "UNAUTHORIZED" {
		t.Errorf("expected error.code=UNAUTHORIZED, got %v", body["error"])
	}
}

func TestCartEndpoint_GetAddPatchDelete(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, hDemoUserEmail)

	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/me/cart", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET cart = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodPost, "/api/v1/me/cart/items", token, map[string]any{"seller_offer_id": hOfferA, "quantity": 1})
	if rec.Code != http.StatusOK {
		t.Fatalf("POST cart/items = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	items, _ := data["items"].([]any)
	var itemID float64
	for _, raw := range items {
		item, _ := raw.(map[string]any)
		if int(item["seller_offer_id"].(float64)) == hOfferA {
			itemID = item["id"].(float64)
		}
	}
	if itemID == 0 {
		t.Fatalf("could not find the just-added item in response: %s", rec.Body.String())
	}
	defer authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), token, nil)

	rec = authedJSONRequest(router, http.MethodPatch, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), token, map[string]any{"quantity": 3})
	if rec.Code != http.StatusOK {
		t.Fatalf("PATCH cart/items/%d = %d, want 200, body=%s", int(itemID), rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodPatch, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), token, map[string]any{"quantity": 0})
	if rec.Code != http.StatusBadRequest {
		t.Errorf("PATCH quantity=0 = %d, want 400", rec.Code)
	}
}

// TestCartEndpoint_InsufficientStock_409 covers Stage 5 §48.
func TestCartEndpoint_InsufficientStock_409(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, hDemoUserEmail)
	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/cart/items", token, map[string]any{"seller_offer_id": hLowStockOffer, "quantity": 999})
	if rec.Code != http.StatusConflict {
		t.Fatalf("POST cart/items with excessive quantity = %d, want 409, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	errObj, _ := body["error"].(map[string]any)
	if errObj["code"] != "INSUFFICIENT_STOCK" {
		t.Errorf("expected error.code=INSUFFICIENT_STOCK, got %v", body["error"])
	}
}

// TestCartEndpoint_PriceAuthority_IgnoresClientPrice covers Stage 5 §12/§49:
// a client-sent price field in the request body must have no effect.
func TestCartEndpoint_PriceAuthority_IgnoresClientPrice(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, hDemoUserEmail)

	reqBody := map[string]any{"seller_offer_id": hOfferB, "quantity": 1, "price": "1.00"}
	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/cart/items", token, reqBody)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST cart/items = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}

	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	items, _ := data["items"].([]any)
	var gotPrice string
	var itemID float64
	for _, raw := range items {
		item, _ := raw.(map[string]any)
		if int(item["seller_offer_id"].(float64)) == hOfferB {
			gotPrice = item["price"].(string)
			itemID = item["id"].(float64)
		}
	}
	defer authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), token, nil)

	if gotPrice == "1.00" || gotPrice == "" {
		t.Errorf("cart item price = %q, expected the real DB offer price (client-sent price must be ignored)", gotPrice)
	}
}

// TestCartEndpoint_CrossUser_ItemNotFound covers Stage 9 §21/§51: with no
// user id left in the URL, "cross-user" can only mean "a different user's
// own valid token" — user 11 (nurlan@example.com) logs in for real and
// still can't reach user 10's cart item, because ownership is checked
// against the authenticated caller, not a URL parameter.
func TestCartEndpoint_CrossUser_ItemNotFound(t *testing.T) {
	router := newFullTestRouter(t)
	tokenA := loginAndGetToken(t, router, hDemoUserEmail)
	tokenB := loginAndGetToken(t, router, "nurlan@example.com")

	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/cart/items", tokenA, map[string]any{"seller_offer_id": hOfferA, "quantity": 1})
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	items, _ := data["items"].([]any)
	var itemID float64
	for _, raw := range items {
		item, _ := raw.(map[string]any)
		if int(item["seller_offer_id"].(float64)) == hOfferA {
			itemID = item["id"].(float64)
		}
	}
	defer authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), tokenA, nil)

	// user 11's own token attempting to touch user 10's cart item.
	rec = authedJSONRequest(router, http.MethodPatch, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), tokenB, map[string]any{"quantity": 2})
	if rec.Code != http.StatusNotFound {
		t.Errorf("cross-user PATCH = %d, want 404", rec.Code)
	}
	rec = authedJSONRequest(router, http.MethodDelete, "/api/v1/me/cart/items/"+strconv.Itoa(int(itemID)), tokenB, nil)
	if rec.Code != http.StatusNotFound {
		t.Errorf("cross-user DELETE = %d, want 404", rec.Code)
	}
}

func TestAddressesEndpoint_CreateUpdateDefaultDelete(t *testing.T) {
	router := newFullTestRouter(t)
	token := loginAndGetToken(t, router, "kidsworld@nova.kz") // no seeded addresses

	rec := authedJSONRequest(router, http.MethodPost, "/api/v1/me/addresses", token, map[string]any{
		"city": "Алматы", "street": "ул. А", "house": "1", "is_default": true,
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST addresses = %d, want 201, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	addrID := int(data["id"].(float64))
	defer authedJSONRequest(router, http.MethodDelete, "/api/v1/me/addresses/"+strconv.Itoa(addrID), token, nil)

	rec = authedJSONRequest(router, http.MethodPost, "/api/v1/me/addresses", token, map[string]any{"street": "ул. Б", "house": "2"})
	if rec.Code != http.StatusBadRequest {
		t.Errorf("POST addresses missing city = %d, want 400, body=%s", rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodPut, "/api/v1/me/addresses/"+strconv.Itoa(addrID), token, map[string]any{
		"city": "Астана", "street": "ул. А", "house": "1",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT addresses/%d = %d, want 200, body=%s", addrID, rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodPatch, "/api/v1/me/addresses/"+strconv.Itoa(addrID)+"/default", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("PATCH addresses/%d/default = %d, want 200, body=%s", addrID, rec.Code, rec.Body.String())
	}

	rec = authedJSONRequest(router, http.MethodDelete, "/api/v1/me/addresses/"+strconv.Itoa(addrID), token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE addresses/%d = %d, want 200, body=%s", addrID, rec.Code, rec.Body.String())
	}
}
