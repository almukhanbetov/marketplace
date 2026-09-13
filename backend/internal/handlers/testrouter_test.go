package handlers_test

import (
	"bytes"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/handlers"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/routes"
	"github.com/nova/marketplace-backend/internal/services"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// testJWTSecret is a fixed, test-only signing secret — never used outside
// this test binary. testDevPassword mirrors seeds.DevPassword (Stage 9
// §65); every seeded account shares it, so handler tests can log in as any
// fixture user via the real /auth/login route instead of hand-rolling a
// token.
const (
	testJWTSecret   = "handler-test-jwt-secret-at-least-32-characters-long"
	testDevPassword = "NovaDev2026"
)

// newFullTestRouter builds the complete router — every handler wired,
// exactly like cmd/api/main.go — against the configured test database.
// Stage 9 requires this because almost every private route now goes
// through real auth middleware, so handler tests need the genuine
// /auth/login + RequireAuth/RequireRole chain, not a partial router.
func newFullTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	pool := testutil.ConnectTestDB(t)
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))

	healthHandler := handlers.NewHealthHandler(pool, logger)
	categoryHandler := handlers.NewCategoryHandler(services.NewCategoryService(repositories.NewCategoryRepository(pool)), logger)
	productRepo := repositories.NewProductRepository(pool)
	productHandler := handlers.NewProductHandler(services.NewProductService(productRepo), logger)
	sellerRepo := repositories.NewSellerRepository(pool)
	sellerHandler := handlers.NewSellerHandler(services.NewSellerService(sellerRepo), logger)

	userRepo := repositories.NewUserRepository(pool)
	favoriteHandler := handlers.NewFavoriteHandler(services.NewFavoriteService(repositories.NewFavoriteRepository(pool), userRepo, productRepo), logger)
	cartHandler := handlers.NewCartHandler(services.NewCartService(repositories.NewCartRepository(pool), userRepo), logger)
	addressHandler := handlers.NewAddressHandler(services.NewAddressService(repositories.NewAddressRepository(pool), userRepo), logger)
	orderHandler := handlers.NewOrderHandler(services.NewOrderService(repositories.NewOrderRepository(pool), userRepo), logger)

	sellerDashboardHandler := handlers.NewSellerDashboardHandler(services.NewSellerDashboardService(repositories.NewSellerDashboardRepository(pool), sellerRepo), logger)
	sellerOfferHandler := handlers.NewSellerOfferHandler(services.NewSellerOfferService(repositories.NewSellerOfferRepository(pool), sellerRepo, productRepo), logger)
	sellerOrderHandler := handlers.NewSellerOrderHandler(services.NewSellerOrderService(repositories.NewSellerOrderRepository(pool), sellerRepo), logger)
	sellerFinanceHandler := handlers.NewSellerFinanceHandler(services.NewSellerFinanceService(repositories.NewSellerFinanceRepository(pool), sellerRepo), logger)
	payoutHandler := handlers.NewPayoutHandler(services.NewPayoutService(repositories.NewPayoutRepository(pool), sellerRepo), logger)

	reviewHandler := handlers.NewReviewHandler(services.NewReviewService(repositories.NewReviewRepository(pool), productRepo), logger)

	adminUserRepo := repositories.NewAdminUserRepository(pool)
	adminCategoryRepo := repositories.NewAdminCategoryRepository(pool)
	adminOverviewHandler := handlers.NewAdminOverviewHandler(services.NewAdminOverviewService(repositories.NewAdminOverviewRepository(pool)), logger)
	adminUserHandler := handlers.NewAdminUserHandler(services.NewAdminUserService(adminUserRepo), logger)
	adminSellerHandler := handlers.NewAdminSellerHandler(services.NewAdminSellerService(repositories.NewAdminSellerRepository(pool)), logger)
	adminProductHandler := handlers.NewAdminProductHandler(services.NewAdminProductService(repositories.NewAdminProductRepository(pool), adminCategoryRepo), logger)
	adminCategoryHandler := handlers.NewAdminCategoryHandler(services.NewAdminCategoryService(adminCategoryRepo), logger)
	adminOrderHandler := handlers.NewAdminOrderHandler(services.NewAdminOrderService(repositories.NewAdminOrderRepository(pool)), logger)
	adminFinanceHandler := handlers.NewAdminFinanceHandler(services.NewAdminFinanceService(repositories.NewAdminFinanceRepository(pool)), logger)
	adminPayoutHandler := handlers.NewAdminPayoutHandler(services.NewAdminPayoutService(repositories.NewAdminPayoutRepository(pool)), logger)

	authRepo := repositories.NewAuthRepository(pool)
	authHandler := handlers.NewAuthHandler(services.NewAuthService(authRepo, adminUserRepo, testJWTSecret, 15*time.Minute, 30*24*time.Hour), logger, false, "")

	gin.SetMode(gin.TestMode)
	return routes.New(routes.Deps{
		Logger:          logger,
		FrontendURL:     "http://localhost:3000",
		HealthHandler:   healthHandler,
		CategoryHandler: categoryHandler,
		ProductHandler:  productHandler,
		SellerHandler:   sellerHandler,
		FavoriteHandler: favoriteHandler,
		CartHandler:     cartHandler,
		AddressHandler:  addressHandler,
		OrderHandler:    orderHandler,

		SellerDashboardHandler: sellerDashboardHandler,
		SellerOfferHandler:     sellerOfferHandler,
		SellerOrderHandler:     sellerOrderHandler,
		SellerFinanceHandler:   sellerFinanceHandler,
		PayoutHandler:          payoutHandler,

		ReviewHandler:        reviewHandler,
		AdminOverviewHandler: adminOverviewHandler,
		AdminUserHandler:     adminUserHandler,
		AdminSellerHandler:   adminSellerHandler,
		AdminProductHandler:  adminProductHandler,
		AdminCategoryHandler: adminCategoryHandler,
		AdminOrderHandler:    adminOrderHandler,
		AdminFinanceHandler:  adminFinanceHandler,
		AdminPayoutHandler:   adminPayoutHandler,

		AuthHandler:         authHandler,
		AuthRepository:      authRepo,
		JWTAccessSecret:     testJWTSecret,
		LoginRateLimiter:    auth.NewRateLimiter(100000, time.Minute),
		RegisterRateLimiter: auth.NewRateLimiter(100000, time.Minute),
		RefreshRateLimiter:  auth.NewRateLimiter(100000, time.Minute),
	})
}

// loginAndGetToken logs in as email (testDevPassword) via the real
// /auth/login route and returns the access token.
func loginAndGetToken(t *testing.T, router *gin.Engine, email string) string {
	t.Helper()
	rec := doJSONRequest(router, http.MethodPost, "/api/v1/auth/login", map[string]any{"email": email, "password": testDevPassword})
	if rec.Code != http.StatusOK {
		t.Fatalf("login as %s = %d, want 200, body=%s", email, rec.Code, rec.Body.String())
	}
	body := decodeBody(t, rec)
	data, _ := body["data"].(map[string]any)
	token, _ := data["access_token"].(string)
	if token == "" {
		t.Fatalf("login as %s: no access_token in response: %s", email, rec.Body.String())
	}
	return token
}

// doJSONRequest issues a request with no Authorization header — for
// public routes and for the auth endpoints themselves (register/login).
func doJSONRequest(router *gin.Engine, method, target string, body any) *httptest.ResponseRecorder {
	return authedJSONRequest(router, method, target, "", body)
}

// authedJSONRequest is doJSONRequest with an Authorization: Bearer header —
// every private-route handler test uses this instead of a URL-embedded id.
func authedJSONRequest(router *gin.Engine, method, target, token string, body any) *httptest.ResponseRecorder {
	var reader io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		reader = bytes.NewReader(b)
	}
	req := httptest.NewRequest(method, target, reader)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}
