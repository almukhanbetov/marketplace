package handlers_test

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/nova/marketplace-backend/internal/testutil"
)

// deleteUserByEmail removes a self-registered test account (and its
// sessions) after the test, so repeat runs against the shared dev DB stay
// clean.
func deleteUserByEmail(t *testing.T, email string) {
	t.Helper()
	pool := testutil.ConnectTestDB(t)
	ctx := context.Background()
	pool.Exec(ctx, `DELETE FROM auth_sessions WHERE user_id = (SELECT id FROM users WHERE email = $1)`, email)
	pool.Exec(ctx, `DELETE FROM users WHERE email = $1`, email)
}

// Stage F2: additive native-client auth transport, selected by
// `X-Client: nova-mobile`. Web behaviour must stay byte-identical; these
// tests pin both sides of that.

// mobileRequest issues a JSON request with the native client marker.
func mobileRequest(router http.Handler, method, target string, body any, bearer string) *httptest.ResponseRecorder {
	var reader io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reader = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, target, reader)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Client", "nova-mobile")
	if bearer != "" {
		req.Header.Set("Authorization", "Bearer "+bearer)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func dataOf(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	body := decodeBody(t, rec)
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("response has no data object: %s", rec.Body.String())
	}
	return data
}

func TestWebLogin_NeverReturnsRefreshTokenInBody(t *testing.T) {
	router := newFullTestRouter(t)

	rec := doJSONRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": "aigerim@example.com", "password": testDevPassword})
	if rec.Code != http.StatusOK {
		t.Fatalf("web login = %d, want 200: %s", rec.Code, rec.Body.String())
	}

	data := dataOf(t, rec)
	if _, present := data["refresh_token"]; present {
		t.Error("web login response body contains refresh_token — it must only ever be in the HttpOnly cookie")
	}
	if data["access_token"] == "" || data["access_token"] == nil {
		t.Error("web login response missing access_token")
	}

	setCookie := rec.Header().Get("Set-Cookie")
	if !strings.Contains(setCookie, "refresh_token=") {
		t.Errorf("web login did not set the refresh_token cookie: %q", setCookie)
	}
	if !strings.Contains(setCookie, "HttpOnly") {
		t.Errorf("web refresh cookie is not HttpOnly: %q", setCookie)
	}
}

func TestMobileLogin_ReturnsRefreshTokenInBodyAndNoCookie(t *testing.T) {
	router := newFullTestRouter(t)

	rec := mobileRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": "aigerim@example.com", "password": testDevPassword}, "")
	if rec.Code != http.StatusOK {
		t.Fatalf("mobile login = %d, want 200: %s", rec.Code, rec.Body.String())
	}

	data := dataOf(t, rec)
	for _, k := range []string{"access_token", "access_expires_at", "refresh_token", "refresh_expires_at", "user"} {
		if v, ok := data[k]; !ok || v == nil || v == "" {
			t.Errorf("mobile login response missing %q", k)
		}
	}
	if rec.Header().Get("Set-Cookie") != "" {
		t.Errorf("mobile login set a cookie, should not: %q", rec.Header().Get("Set-Cookie"))
	}

	user, _ := data["user"].(map[string]any)
	if user["role"] != "customer" {
		t.Errorf("mobile login user.role = %v, want customer", user["role"])
	}
	if _, ok := user["seller_id"]; !ok {
		t.Error("mobile login user is missing seller_id key (should be present, null for a customer)")
	}
	if _, leaked := user["password_hash"]; leaked {
		t.Error("mobile login user leaked password_hash")
	}
}

func TestMobileRegister_ReturnsSessionTokens(t *testing.T) {
	router := newFullTestRouter(t)
	email := uniqueTestEmail("f2-mobile-register")
	defer deleteUserByEmail(t, email)

	rec := mobileRequest(router, http.MethodPost, "/api/v1/auth/register", map[string]any{
		"email": email, "full_name": "F2 Mobile", "password": testDevPassword,
	}, "")
	if rec.Code != http.StatusCreated {
		t.Fatalf("mobile register = %d, want 201: %s", rec.Code, rec.Body.String())
	}

	data := dataOf(t, rec)
	for _, k := range []string{"access_token", "refresh_token", "refresh_expires_at", "user"} {
		if data[k] == nil || data[k] == "" {
			t.Errorf("mobile register response missing %q", k)
		}
	}
	user, _ := data["user"].(map[string]any)
	if user["role"] != "customer" {
		t.Errorf("mobile register role = %v, want customer", user["role"])
	}

	// The returned access token actually works.
	access, _ := data["access_token"].(string)
	me := mobileRequest(router, http.MethodGet, "/api/v1/auth/me", nil, access)
	if me.Code != http.StatusOK {
		t.Fatalf("me with fresh mobile-register token = %d, want 200", me.Code)
	}
}

func TestWebRegister_DoesNotReturnTokens(t *testing.T) {
	router := newFullTestRouter(t)
	email := uniqueTestEmail("f2-web-register")
	defer deleteUserByEmail(t, email)

	rec := doJSONRequest(router, http.MethodPost, "/api/v1/auth/register", map[string]any{
		"email": email, "full_name": "F2 Web", "password": testDevPassword,
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("web register = %d, want 201: %s", rec.Code, rec.Body.String())
	}
	data := dataOf(t, rec)
	if _, present := data["refresh_token"]; present {
		t.Error("web register returned a refresh_token — web must not")
	}
	if _, present := data["access_token"]; present {
		t.Error("web register returned an access_token — unchanged web behaviour is user-only")
	}
}

func TestMobileRefresh_RotatesAndRejectsReuse(t *testing.T) {
	router := newFullTestRouter(t)

	login := mobileRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": "nurlan@example.com", "password": testDevPassword}, "")
	refreshA, _ := dataOf(t, login)["refresh_token"].(string)
	if refreshA == "" {
		t.Fatal("no refresh token from mobile login")
	}

	// refresh A -> B
	r1 := mobileRequest(router, http.MethodPost, "/api/v1/auth/refresh",
		map[string]any{"refresh_token": refreshA}, "")
	if r1.Code != http.StatusOK {
		t.Fatalf("mobile refresh A = %d, want 200: %s", r1.Code, r1.Body.String())
	}
	refreshB, _ := dataOf(t, r1)["refresh_token"].(string)
	if refreshB == "" || refreshB == refreshA {
		t.Fatalf("refresh did not rotate the token (A=%q B=%q)", refreshA, refreshB)
	}

	// reuse A -> rejected (401 SESSION_EXPIRED)
	reuse := mobileRequest(router, http.MethodPost, "/api/v1/auth/refresh",
		map[string]any{"refresh_token": refreshA}, "")
	if reuse.Code != http.StatusUnauthorized {
		t.Fatalf("reusing rotated token A = %d, want 401: %s", reuse.Code, reuse.Body.String())
	}

	// reuse detection revoked the whole chain -> B is now dead too
	afterReuse := mobileRequest(router, http.MethodPost, "/api/v1/auth/refresh",
		map[string]any{"refresh_token": refreshB}, "")
	if afterReuse.Code != http.StatusUnauthorized {
		t.Fatalf("token B after A-reuse = %d, want 401 (chain revoked): %s", afterReuse.Code, afterReuse.Body.String())
	}
}

func TestMobileLogout_RevokesSession(t *testing.T) {
	router := newFullTestRouter(t)

	login := mobileRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": "saltanat@example.com", "password": testDevPassword}, "")
	refresh, _ := dataOf(t, login)["refresh_token"].(string)

	out := mobileRequest(router, http.MethodPost, "/api/v1/auth/logout",
		map[string]any{"refresh_token": refresh}, "")
	if out.Code != http.StatusOK {
		t.Fatalf("mobile logout = %d, want 200: %s", out.Code, out.Body.String())
	}

	after := mobileRequest(router, http.MethodPost, "/api/v1/auth/refresh",
		map[string]any{"refresh_token": refresh}, "")
	if after.Code != http.StatusUnauthorized {
		t.Fatalf("refresh after mobile logout = %d, want 401: %s", after.Code, after.Body.String())
	}
}

func TestMobileLogin_InactiveAccountStillBlocked(t *testing.T) {
	router := newFullTestRouter(t)
	email := uniqueTestEmail("f2-mobile-inactive")
	defer deleteUserByEmail(t, email)

	reg := mobileRequest(router, http.MethodPost, "/api/v1/auth/register", map[string]any{
		"email": email, "full_name": "F2 Inactive", "password": testDevPassword,
	}, "")
	if reg.Code != http.StatusCreated {
		t.Fatalf("register = %d: %s", reg.Code, reg.Body.String())
	}

	pool := testutil.ConnectTestDB(t)
	if _, err := pool.Exec(context.Background(), `UPDATE users SET is_active = FALSE WHERE email = $1`, email); err != nil {
		t.Fatalf("deactivate: %v", err)
	}

	rec := mobileRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": email, "password": testDevPassword}, "")
	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("inactive mobile login = %d, want 401: %s", rec.Code, rec.Body.String())
	}
	if code, _ := decodeBody(t, rec)["error"].(map[string]any); code["code"] != "ACCOUNT_DISABLED" {
		t.Errorf("inactive mobile login code = %v, want ACCOUNT_DISABLED", code["code"])
	}
}

func TestRequestWithoutMobileMarker_NeverGetsBodyRefreshToken(t *testing.T) {
	router := newFullTestRouter(t)
	// Same credentials, no X-Client header -> web transport.
	rec := doJSONRequest(router, http.MethodPost, "/api/v1/auth/login",
		map[string]any{"email": "beautylab@nova.kz", "password": testDevPassword})
	if _, present := dataOf(t, rec)["refresh_token"]; present {
		t.Error("login without X-Client returned refresh_token in body")
	}
}
