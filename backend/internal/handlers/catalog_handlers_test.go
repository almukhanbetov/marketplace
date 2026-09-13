package handlers_test

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/handlers"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/routes"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// newTestRouter builds the real router — real repositories, real services,
// real handlers — against the configured test database, exactly like
// cmd/api/main.go does. Skips (not fails) if no database is configured.
func newTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	pool := testutil.ConnectTestDB(t)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	healthHandler := handlers.NewHealthHandler(pool, logger)
	categoryHandler := handlers.NewCategoryHandler(services.NewCategoryService(repositories.NewCategoryRepository(pool)), logger)
	productHandler := handlers.NewProductHandler(services.NewProductService(repositories.NewProductRepository(pool)), logger)
	sellerHandler := handlers.NewSellerHandler(services.NewSellerService(repositories.NewSellerRepository(pool)), logger)

	gin.SetMode(gin.TestMode)
	return routes.New(routes.Deps{
		Logger:          logger,
		FrontendURL:     "http://localhost:3000",
		HealthHandler:   healthHandler,
		CategoryHandler: categoryHandler,
		ProductHandler:  productHandler,
		SellerHandler:   sellerHandler,
	})
}

func doRequest(router *gin.Engine, method, target string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(method, target, nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func decodeBody(t *testing.T, rec *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v\nbody: %s", err, rec.Body.String())
	}
	return body
}

func TestHealthEndpoint_StillWorks(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/health")
	if rec.Code != http.StatusOK {
		t.Errorf("GET /health = %d, want 200", rec.Code)
	}
}

func TestCategoriesEndpoint(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/categories")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/categories = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, ok := body["data"].([]any)
	if !ok || len(data) < 10 {
		t.Errorf("expected >= 10 categories in data, got %v", body["data"])
	}
}

func TestProductsEndpoint(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/products")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/products = %d, want 200, body=%s", rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	meta, ok := body["meta"].(map[string]any)
	if !ok {
		t.Fatalf("expected meta object, got %v", body["meta"])
	}
	if total, _ := meta["total"].(float64); total < 30 {
		t.Errorf("meta.total = %v, want >= 30", meta["total"])
	}
}

// TestProductDetailAndOffers_DynamicID discovers a real product id from the
// list endpoint (rather than hardcoding one) and exercises the detail and
// offers endpoints against it, per Stage 3 §44.
func TestProductDetailAndOffers_DynamicID(t *testing.T) {
	router := newTestRouter(t)

	listRec := doRequest(router, http.MethodGet, "/api/v1/products?limit=1")
	listBody := decodeBody(t, listRec)
	items, _ := listBody["data"].([]any)
	if len(items) == 0 {
		t.Fatal("expected at least one product to discover an id from")
	}
	first, _ := items[0].(map[string]any)
	idFloat, _ := first["id"].(float64)
	id := int(idFloat)
	if id == 0 {
		t.Fatalf("could not discover a product id from list response: %v", first)
	}

	detailRec := doRequest(router, http.MethodGet, "/api/v1/products/"+strconv.Itoa(id))
	if detailRec.Code != http.StatusOK {
		t.Errorf("GET /api/v1/products/%d = %d, want 200", id, detailRec.Code)
	}

	offersRec := doRequest(router, http.MethodGet, "/api/v1/products/"+strconv.Itoa(id)+"/offers")
	if offersRec.Code != http.StatusOK {
		t.Errorf("GET /api/v1/products/%d/offers = %d, want 200", id, offersRec.Code)
	}
}

func TestProductsEndpoint_UnknownID_404(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/products/999999999")
	if rec.Code != http.StatusNotFound {
		t.Errorf("GET /api/v1/products/999999999 = %d, want 404", rec.Code)
	}
	body := decodeBody(t, rec)
	errObj, ok := body["error"].(map[string]any)
	if !ok || errObj["code"] != "PRODUCT_NOT_FOUND" {
		t.Errorf("expected error.code=PRODUCT_NOT_FOUND, got %v", body["error"])
	}
}

func TestProductsEndpoint_InvalidSort_400(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/products?sort=not_a_real_sort")
	if rec.Code != http.StatusBadRequest {
		t.Errorf("GET /api/v1/products?sort=invalid = %d, want 400", rec.Code)
	}
}

func TestSellersEndpoint(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/sellers")
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /api/v1/sellers = %d, want 200", rec.Code)
	}
	body := decodeBody(t, rec)
	data, ok := body["data"].([]any)
	if !ok || len(data) < 3 {
		t.Errorf("expected >= 3 sellers, got %v", body["data"])
	}
}

func TestSellersEndpoint_UnknownID_404(t *testing.T) {
	router := newTestRouter(t)
	rec := doRequest(router, http.MethodGet, "/api/v1/sellers/999999999")
	if rec.Code != http.StatusNotFound {
		t.Errorf("GET /api/v1/sellers/999999999 = %d, want 404", rec.Code)
	}
}
