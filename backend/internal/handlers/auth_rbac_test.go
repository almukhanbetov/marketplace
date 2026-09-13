package handlers_test

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/nova/marketplace-backend/internal/testutil"
)

// uniqueTestEmail returns a fresh email every call — self-registered test
// accounts never collide with a seeded fixture or another package's run.
func uniqueTestEmail(name string) string {
	return fmt.Sprintf("%s-%d@example.com", name, time.Now().UnixNano())
}

// TestRBACMatrix_PublicProduct covers Stage 9 §26/§59: catalog reads need
// no authentication at all.
func TestRBACMatrix_PublicProduct(t *testing.T) {
	router := newFullTestRouter(t)
	rec := doJSONRequest(router, http.MethodGet, "/api/v1/products/1", nil)
	if rec.Code != http.StatusOK {
		t.Errorf("GET /products/1 anonymous = %d, want 200", rec.Code)
	}
}

// TestRBACMatrix_MeCart covers Stage 9 §59: anonymous -> 401, any
// authenticated role -> 200 (buying is not restricted to role=customer —
// a seller or admin account is still a person who can shop).
func TestRBACMatrix_MeCart(t *testing.T) {
	router := newFullTestRouter(t)

	rec := doJSONRequest(router, http.MethodGet, "/api/v1/me/cart", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("GET /me/cart anonymous = %d, want 401", rec.Code)
	}

	customerToken := loginAndGetToken(t, router, "aigerim@example.com")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/me/cart", customerToken, nil)
	if rec.Code != http.StatusOK {
		t.Errorf("GET /me/cart customer = %d, want 200", rec.Code)
	}
}

// TestRBACMatrix_SellerDashboard is the exact matrix Stage 9 §59
// specifies: anonymous -> 401, customer -> 403, seller -> 200.
func TestRBACMatrix_SellerDashboard(t *testing.T) {
	router := newFullTestRouter(t)

	rec := doJSONRequest(router, http.MethodGet, "/api/v1/seller/dashboard", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("GET /seller/dashboard anonymous = %d, want 401", rec.Code)
	}

	customerToken := loginAndGetToken(t, router, "aigerim@example.com")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/seller/dashboard", customerToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Errorf("GET /seller/dashboard customer = %d, want 403", rec.Code)
	}

	sellerToken := loginAndGetToken(t, router, "techstore@nova.kz")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/seller/dashboard", sellerToken, nil)
	if rec.Code != http.StatusOK {
		t.Errorf("GET /seller/dashboard seller = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
}

// TestRBACMatrix_Admin is the exact matrix Stage 9 §53 calls "critical":
// no token -> 401, customer token -> 403, seller token -> 403, admin
// token -> 200.
func TestRBACMatrix_Admin(t *testing.T) {
	router := newFullTestRouter(t)

	rec := doJSONRequest(router, http.MethodGet, "/api/v1/admin/overview", nil)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("GET /admin/overview anonymous = %d, want 401", rec.Code)
	}

	customerToken := loginAndGetToken(t, router, "aigerim@example.com")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/admin/overview", customerToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Errorf("GET /admin/overview customer = %d, want 403", rec.Code)
	}

	sellerToken := loginAndGetToken(t, router, "techstore@nova.kz")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/admin/overview", sellerToken, nil)
	if rec.Code != http.StatusForbidden {
		t.Errorf("GET /admin/overview seller = %d, want 403", rec.Code)
	}

	adminToken := loginAndGetToken(t, router, "admin@nova.kz")
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/admin/overview", adminToken, nil)
	if rec.Code != http.StatusOK {
		t.Errorf("GET /admin/overview admin = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
}

// TestAccountDeactivation_BlocksAlreadyIssuedAccessToken covers Stage 9
// §12/§60: an access token issued before deactivation is still
// cryptographically valid (unexpired signature) but must stop working on
// the very next request, because RequireAuth reloads the user fresh from
// the database rather than trusting the JWT's claims. Uses a freshly
// self-registered user — never a seeded fixture — so no other package's
// concurrent test can be affected by flipping is_active.
func TestAccountDeactivation_BlocksAlreadyIssuedAccessToken(t *testing.T) {
	router := newFullTestRouter(t)
	pool := testutil.ConnectTestDB(t)

	email := uniqueTestEmail("deactivation-handler-test")
	regRec := doJSONRequest(router, http.MethodPost, "/api/v1/auth/register", map[string]any{
		"email": email, "full_name": "Deactivation Test", "password": testDevPassword,
	})
	if regRec.Code != http.StatusCreated {
		t.Fatalf("register = %d, want 201, body=%s", regRec.Code, regRec.Body.String())
	}
	body := decodeBody(t, regRec)
	data, _ := body["data"].(map[string]any)
	userID := int64(data["id"].(float64))
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM auth_sessions WHERE user_id = $1`, userID)
		pool.Exec(context.Background(), `DELETE FROM users WHERE id = $1`, userID)
	})

	token := loginAndGetToken(t, router, email)

	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/auth/me", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /auth/me before deactivation = %d, want 200", rec.Code)
	}

	if _, err := pool.Exec(context.Background(), `UPDATE users SET is_active = FALSE WHERE id = $1`, userID); err != nil {
		t.Fatalf("deactivate user: %v", err)
	}

	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/auth/me", token, nil)
	if rec.Code != http.StatusUnauthorized {
		t.Errorf("GET /auth/me with a still-unexpired token AFTER deactivation = %d, want 401 (stale JWT claim must not grant access)", rec.Code)
	}
	respBody := decodeBody(t, rec)
	errObj, _ := respBody["error"].(map[string]any)
	if errObj["code"] != "ACCOUNT_DISABLED" {
		t.Errorf("expected error.code=ACCOUNT_DISABLED, got %v", respBody["error"])
	}

	if _, err := pool.Exec(context.Background(), `UPDATE users SET is_active = TRUE WHERE id = $1`, userID); err != nil {
		t.Fatalf("reactivate user: %v", err)
	}
	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/auth/me", token, nil)
	if rec.Code != http.StatusOK {
		t.Errorf("GET /auth/me after reactivation = %d, want 200 (same still-unexpired token works again)", rec.Code)
	}
}

// TestSellerDeactivation_BlocksSellerPrivateRoutes covers Stage 9 §24/§61:
// deactivating the sellers row (not the user) also blocks seller-private
// routes for that account, even though the user itself is still active
// and the access token still parses fine. Uses seller 4 (GadgetPro) —
// unreferenced by any is_active mutation in any other test/package (see
// admin_seller_service_test.go's own allocation note for seller 3; this
// is a distinct seller in a distinct package).
func TestSellerDeactivation_BlocksSellerPrivateRoutes(t *testing.T) {
	router := newFullTestRouter(t)
	pool := testutil.ConnectTestDB(t)
	const sellerID = int64(4)

	t.Cleanup(func() {
		pool.Exec(context.Background(), `UPDATE sellers SET is_active = TRUE WHERE id = $1`, sellerID)
	})

	token := loginAndGetToken(t, router, "gadgetpro@nova.kz")

	rec := authedJSONRequest(router, http.MethodGet, "/api/v1/seller/dashboard", token, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /seller/dashboard before deactivation = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}

	if _, err := pool.Exec(context.Background(), `UPDATE sellers SET is_active = FALSE WHERE id = $1`, sellerID); err != nil {
		t.Fatalf("deactivate seller %d: %v", sellerID, err)
	}

	rec = authedJSONRequest(router, http.MethodGet, "/api/v1/seller/dashboard", token, nil)
	if rec.Code != http.StatusForbidden {
		t.Errorf("GET /seller/dashboard after seller deactivation = %d, want 403", rec.Code)
	}
}
