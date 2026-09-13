// Command api is the marketplace REST API server. main() only assembles the
// application (config → database → handlers → router → server) and manages
// its lifecycle — all real logic lives in internal/.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/config"
	"github.com/nova/marketplace-backend/internal/database"
	"github.com/nova/marketplace-backend/internal/handlers"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/routes"
	"github.com/nova/marketplace-backend/internal/services"
)

// Rate-limit budgets for the auth endpoints (Stage 9 §35) — generous
// enough not to bother a real user who mistypes a password a couple of
// times, tight enough to slow down a naive brute-force loop. Single
// in-process limiter; see auth.RateLimiter's doc comment for why that's an
// honest, documented tradeoff rather than a production-grade defense.
const (
	loginRateLimit     = 10
	loginRateWindow    = time.Minute
	registerRateLimit  = 5
	registerRateWindow = time.Minute
	refreshRateLimit   = 30
	refreshRateWindow  = time.Minute
)

const (
	readHeaderTimeout = 5 * time.Second
	readTimeout       = 10 * time.Second
	writeTimeout      = 15 * time.Second
	idleTimeout       = 60 * time.Second
	shutdownTimeout   = 10 * time.Second
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	if err := run(logger); err != nil {
		logger.Error("fatal startup error", "error", err)
		os.Exit(1)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	logger.Info("configuration loaded", "app_env", cfg.AppEnv, "port", cfg.Port)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := database.NewPool(ctx, cfg.ConnString(), cfg.DBConnectTimeout)
	if err != nil {
		return err
	}
	logger.Info("connected to PostgreSQL")
	defer pool.Close()

	healthHandler := handlers.NewHealthHandler(pool, logger)

	categoryRepo := repositories.NewCategoryRepository(pool)
	productRepo := repositories.NewProductRepository(pool)
	sellerRepo := repositories.NewSellerRepository(pool)
	userRepo := repositories.NewUserRepository(pool)
	favoriteRepo := repositories.NewFavoriteRepository(pool)
	cartRepo := repositories.NewCartRepository(pool)
	addressRepo := repositories.NewAddressRepository(pool)
	orderRepo := repositories.NewOrderRepository(pool)
	sellerDashboardRepo := repositories.NewSellerDashboardRepository(pool)
	sellerOfferRepo := repositories.NewSellerOfferRepository(pool)
	sellerOrderRepo := repositories.NewSellerOrderRepository(pool)
	sellerFinanceRepo := repositories.NewSellerFinanceRepository(pool)
	payoutRepo := repositories.NewPayoutRepository(pool)
	reviewRepo := repositories.NewReviewRepository(pool)
	adminOverviewRepo := repositories.NewAdminOverviewRepository(pool)
	adminUserRepo := repositories.NewAdminUserRepository(pool)
	adminSellerRepo := repositories.NewAdminSellerRepository(pool)
	adminProductRepo := repositories.NewAdminProductRepository(pool)
	adminCategoryRepo := repositories.NewAdminCategoryRepository(pool)
	adminOrderRepo := repositories.NewAdminOrderRepository(pool)
	adminFinanceRepo := repositories.NewAdminFinanceRepository(pool)
	adminPayoutRepo := repositories.NewAdminPayoutRepository(pool)
	authRepo := repositories.NewAuthRepository(pool)

	categoryService := services.NewCategoryService(categoryRepo)
	productService := services.NewProductService(productRepo)
	sellerService := services.NewSellerService(sellerRepo)
	favoriteService := services.NewFavoriteService(favoriteRepo, userRepo, productRepo)
	cartService := services.NewCartService(cartRepo, userRepo)
	addressService := services.NewAddressService(addressRepo, userRepo)
	orderService := services.NewOrderService(orderRepo, userRepo)
	sellerDashboardService := services.NewSellerDashboardService(sellerDashboardRepo, sellerRepo)
	sellerOfferService := services.NewSellerOfferService(sellerOfferRepo, sellerRepo, productRepo)
	sellerOrderService := services.NewSellerOrderService(sellerOrderRepo, sellerRepo)
	sellerFinanceService := services.NewSellerFinanceService(sellerFinanceRepo, sellerRepo)
	payoutService := services.NewPayoutService(payoutRepo, sellerRepo)
	reviewService := services.NewReviewService(reviewRepo, productRepo)
	adminOverviewService := services.NewAdminOverviewService(adminOverviewRepo)
	adminUserService := services.NewAdminUserService(adminUserRepo)
	adminSellerService := services.NewAdminSellerService(adminSellerRepo)
	adminProductService := services.NewAdminProductService(adminProductRepo, adminCategoryRepo)
	adminCategoryService := services.NewAdminCategoryService(adminCategoryRepo)
	adminOrderService := services.NewAdminOrderService(adminOrderRepo)
	adminFinanceService := services.NewAdminFinanceService(adminFinanceRepo)
	adminPayoutService := services.NewAdminPayoutService(adminPayoutRepo)
	authService := services.NewAuthService(authRepo, adminUserRepo, cfg.JWTAccessSecret, cfg.JWTAccessTTL, cfg.RefreshTokenTTL)

	router := routes.New(routes.Deps{
		Logger:                 logger,
		FrontendURL:            cfg.FrontendURL,
		IsProduction:           cfg.IsProduction(),
		HealthHandler:          healthHandler,
		CategoryHandler:        handlers.NewCategoryHandler(categoryService, logger),
		ProductHandler:         handlers.NewProductHandler(productService, logger),
		SellerHandler:          handlers.NewSellerHandler(sellerService, logger),
		FavoriteHandler:        handlers.NewFavoriteHandler(favoriteService, logger),
		CartHandler:            handlers.NewCartHandler(cartService, logger),
		AddressHandler:         handlers.NewAddressHandler(addressService, logger),
		OrderHandler:           handlers.NewOrderHandler(orderService, logger),
		SellerDashboardHandler: handlers.NewSellerDashboardHandler(sellerDashboardService, logger),
		SellerOfferHandler:     handlers.NewSellerOfferHandler(sellerOfferService, logger),
		SellerOrderHandler:     handlers.NewSellerOrderHandler(sellerOrderService, logger),
		SellerFinanceHandler:   handlers.NewSellerFinanceHandler(sellerFinanceService, logger),
		PayoutHandler:          handlers.NewPayoutHandler(payoutService, logger),
		ReviewHandler:          handlers.NewReviewHandler(reviewService, logger),
		AdminOverviewHandler:   handlers.NewAdminOverviewHandler(adminOverviewService, logger),
		AdminUserHandler:       handlers.NewAdminUserHandler(adminUserService, logger),
		AdminSellerHandler:     handlers.NewAdminSellerHandler(adminSellerService, logger),
		AdminProductHandler:    handlers.NewAdminProductHandler(adminProductService, logger),
		AdminCategoryHandler:   handlers.NewAdminCategoryHandler(adminCategoryService, logger),
		AdminOrderHandler:      handlers.NewAdminOrderHandler(adminOrderService, logger),
		AdminFinanceHandler:    handlers.NewAdminFinanceHandler(adminFinanceService, logger),
		AdminPayoutHandler:     handlers.NewAdminPayoutHandler(adminPayoutService, logger),
		AuthHandler:            handlers.NewAuthHandler(authService, logger, cfg.CookieSecure, cfg.CookieDomain),
		AuthRepository:         authRepo,
		JWTAccessSecret:        cfg.JWTAccessSecret,
		LoginRateLimiter:       auth.NewRateLimiter(loginRateLimit, loginRateWindow),
		RegisterRateLimiter:    auth.NewRateLimiter(registerRateLimit, registerRateWindow),
		RefreshRateLimiter:     auth.NewRateLimiter(refreshRateLimit, refreshRateWindow),
	})

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: readHeaderTimeout,
		ReadTimeout:       readTimeout,
		WriteTimeout:      writeTimeout,
		IdleTimeout:       idleTimeout,
	}

	serverErr := make(chan error, 1)
	go func() {
		logger.Info("server listening", "addr", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
			return
		}
		serverErr <- nil
	}()

	select {
	case <-ctx.Done():
		logger.Info("shutdown signal received")
	case err := <-serverErr:
		if err != nil {
			return err
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), shutdownTimeout)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
		return err
	}

	logger.Info("server shut down cleanly")
	return nil
}
