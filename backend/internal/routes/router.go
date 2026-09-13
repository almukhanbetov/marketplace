// Package routes wires middleware and handlers onto a gin.Engine. It is the
// only place that knows the full URL map of the API.
package routes

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/handlers"
	"github.com/nova/marketplace-backend/internal/middleware"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// Deps are the dependencies the router needs to build handlers. It grows as
// repositories/services are introduced in later stages.
type Deps struct {
	Logger          *slog.Logger
	FrontendURL     string
	IsProduction    bool
	HealthHandler   *handlers.HealthHandler
	CategoryHandler *handlers.CategoryHandler
	ProductHandler  *handlers.ProductHandler
	SellerHandler   *handlers.SellerHandler
	FavoriteHandler *handlers.FavoriteHandler
	CartHandler     *handlers.CartHandler
	AddressHandler  *handlers.AddressHandler
	OrderHandler    *handlers.OrderHandler

	// Stage 7: seller operations backend.
	SellerDashboardHandler *handlers.SellerDashboardHandler
	SellerOfferHandler     *handlers.SellerOfferHandler
	SellerOrderHandler     *handlers.SellerOrderHandler
	SellerFinanceHandler   *handlers.SellerFinanceHandler
	PayoutHandler          *handlers.PayoutHandler

	// Stage 8: admin backend + reviews. ReviewHandler.ListPublic is the one
	// non-admin route in this group (GET /products/:id/reviews).
	ReviewHandler        *handlers.ReviewHandler
	AdminOverviewHandler *handlers.AdminOverviewHandler
	AdminUserHandler     *handlers.AdminUserHandler
	AdminSellerHandler   *handlers.AdminSellerHandler
	AdminProductHandler  *handlers.AdminProductHandler
	AdminCategoryHandler *handlers.AdminCategoryHandler
	AdminOrderHandler    *handlers.AdminOrderHandler
	AdminFinanceHandler  *handlers.AdminFinanceHandler
	AdminPayoutHandler   *handlers.AdminPayoutHandler

	// Stage 9: authentication/RBAC. AuthRepository and JWTAccessSecret are
	// needed directly by RequireAuth (it re-loads the user fresh from the
	// database on every request rather than trusting the JWT alone — see
	// middleware.RequireAuth's doc comment).
	AuthHandler     *handlers.AuthHandler
	AuthRepository  *repositories.AuthRepository
	JWTAccessSecret string

	// Minimal in-process rate limiters for the three auth endpoints most
	// worth guarding against brute force (Stage 9 §35).
	LoginRateLimiter    *auth.RateLimiter
	RegisterRateLimiter *auth.RateLimiter
	RefreshRateLimiter  *auth.RateLimiter
}

// New builds a fully configured gin.Engine: global middleware first, then
// the versioned API route group.
func New(deps Deps) *gin.Engine {
	if deps.IsProduction {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()

	router.Use(
		middleware.RequestID(),
		middleware.Recovery(deps.Logger),
		middleware.Logger(deps.Logger),
		middleware.CORS(deps.FrontendURL),
	)

	router.GET("/health", deps.HealthHandler.Health)

	requireAuth := middleware.RequireAuth(deps.JWTAccessSecret, deps.AuthRepository)

	apiV1 := router.Group("/api/v1")
	{
		// ---- Public routes (Stage 9 §26: no auth required) ----
		apiV1.GET("/categories", deps.CategoryHandler.List)
		apiV1.GET("/categories/:id", deps.CategoryHandler.Get)

		apiV1.GET("/products", deps.ProductHandler.List)
		apiV1.GET("/products/:id", deps.ProductHandler.Get)
		apiV1.GET("/products/:id/offers", deps.ProductHandler.ListOffers)
		apiV1.GET("/products/:id/reviews", deps.ReviewHandler.ListPublic)

		apiV1.GET("/sellers", deps.SellerHandler.List)
		apiV1.GET("/sellers/:id", deps.SellerHandler.Get)
		apiV1.GET("/sellers/:id/products", deps.SellerHandler.ListProducts)

		// ---- Auth (Stage 9 §8-§17) ----
		authGroup := apiV1.Group("/auth")
		{
			authGroup.POST("/register", middleware.RateLimit(deps.RegisterRateLimiter, "register"), deps.AuthHandler.Register)
			authGroup.POST("/login", middleware.RateLimit(deps.LoginRateLimiter, "login"), deps.AuthHandler.Login)
			authGroup.POST("/refresh", middleware.RateLimit(deps.RefreshRateLimiter, "refresh"), deps.AuthHandler.Refresh)
			authGroup.POST("/logout", deps.AuthHandler.Logout)
			authGroup.POST("/logout-all", requireAuth, deps.AuthHandler.LogoutAll)
			authGroup.GET("/me", requireAuth, deps.AuthHandler.Me)
		}

		// ---- Customer-private routes (Stage 9 §21/§22): identity comes
		// exclusively from the authenticated caller — no :userId in any of
		// these URLs, so there is nothing to spoof by editing the address
		// bar. The old /users/:userId/... routes are gone entirely, not
		// just hidden (§68).
		me := apiV1.Group("/me")
		me.Use(requireAuth)
		{
			me.GET("/favorites", deps.FavoriteHandler.List)
			me.POST("/favorites/:productId", deps.FavoriteHandler.Add)
			me.DELETE("/favorites/:productId", deps.FavoriteHandler.Remove)

			me.GET("/cart", deps.CartHandler.Get)
			me.POST("/cart/items", deps.CartHandler.AddItem)
			me.PATCH("/cart/items/:itemId", deps.CartHandler.UpdateItem)
			me.DELETE("/cart/items/:itemId", deps.CartHandler.RemoveItem)
			me.DELETE("/cart", deps.CartHandler.Clear)

			me.GET("/addresses", deps.AddressHandler.List)
			me.POST("/addresses", deps.AddressHandler.Create)
			me.PUT("/addresses/:id", deps.AddressHandler.Update)
			me.PATCH("/addresses/:id/default", deps.AddressHandler.SetDefault)
			me.DELETE("/addresses/:id", deps.AddressHandler.Delete)

			me.POST("/orders", deps.OrderHandler.Create)
			me.GET("/orders", deps.OrderHandler.List)
			me.GET("/orders/:orderId", deps.OrderHandler.Get)
		}

		// ---- Seller-private routes (Stage 9 §23/§24/§52): seller id
		// comes exclusively from the authenticated caller's linked ACTIVE
		// seller account. No seller id appears anywhere in these URLs, so
		// a seller can never reach another seller's dashboard/offers/
		// orders/finance/payouts by editing an id. Public
		// /sellers/:id[/products] (above) is unaffected.
		seller := apiV1.Group("/seller")
		seller.Use(requireAuth, middleware.RequireRole("seller"), middleware.RequireActiveSeller())
		{
			seller.GET("/dashboard", deps.SellerDashboardHandler.GetSummary)

			seller.GET("/offers", deps.SellerOfferHandler.List)
			seller.POST("/offers", deps.SellerOfferHandler.Create)
			seller.PUT("/offers/:offerId", deps.SellerOfferHandler.Update)
			seller.PATCH("/offers/:offerId/status", deps.SellerOfferHandler.UpdateStatus)

			seller.GET("/inventory", deps.SellerOfferHandler.ListInventory)
			seller.PATCH("/inventory/:offerId", deps.SellerOfferHandler.UpdateInventory)

			// Read-only (Stage 7 §16/§17) — no status-mutation route.
			seller.GET("/orders", deps.SellerOrderHandler.List)
			seller.GET("/orders/:orderId", deps.SellerOrderHandler.Get)

			seller.GET("/finance", deps.SellerFinanceHandler.GetSummary)

			seller.GET("/payouts", deps.PayoutHandler.List)
			seller.POST("/payouts", deps.PayoutHandler.Create)
		}

		// ---- Admin routes (Stage 9 §25): require authentication AND
		// role == admin. Anonymous -> 401, wrong role -> 403 (§27/§53).
		admin := apiV1.Group("/admin")
		admin.Use(requireAuth, middleware.RequireRole("admin"))
		{
			admin.GET("/overview", deps.AdminOverviewHandler.GetSummary)

			admin.GET("/users", deps.AdminUserHandler.List)
			admin.GET("/users/:id", deps.AdminUserHandler.Get)
			admin.PATCH("/users/:id/status", deps.AdminUserHandler.UpdateStatus)

			admin.GET("/sellers", deps.AdminSellerHandler.List)
			admin.GET("/sellers/:id", deps.AdminSellerHandler.Get)
			admin.PATCH("/sellers/:id/status", deps.AdminSellerHandler.UpdateStatus)
			admin.PATCH("/sellers/:id/verification", deps.AdminSellerHandler.UpdateVerification)

			admin.GET("/products", deps.AdminProductHandler.List)
			admin.GET("/products/:id", deps.AdminProductHandler.Get)
			admin.POST("/products", deps.AdminProductHandler.Create)
			admin.PUT("/products/:id", deps.AdminProductHandler.Update)
			admin.PATCH("/products/:id/status", deps.AdminProductHandler.UpdateStatus)

			admin.GET("/categories", deps.AdminCategoryHandler.List)
			admin.POST("/categories", deps.AdminCategoryHandler.Create)
			admin.PUT("/categories/:id", deps.AdminCategoryHandler.Update)
			admin.PATCH("/categories/:id/status", deps.AdminCategoryHandler.UpdateStatus)

			// Read-only (Stage 8 §22) — no order status-mutation route.
			admin.GET("/orders", deps.AdminOrderHandler.List)
			admin.GET("/orders/:id", deps.AdminOrderHandler.Get)

			admin.GET("/payments", deps.AdminFinanceHandler.ListPayments)
			admin.GET("/commissions", deps.AdminFinanceHandler.ListCommissions)

			admin.GET("/payouts", deps.AdminPayoutHandler.List)
			admin.GET("/payouts/:id", deps.AdminPayoutHandler.Get)
			admin.PATCH("/payouts/:id/status", deps.AdminPayoutHandler.UpdateStatus)

			admin.GET("/reviews", deps.ReviewHandler.ListAdmin)
			admin.GET("/reviews/:id", deps.ReviewHandler.GetAdmin)
			admin.PATCH("/reviews/:id/visibility", deps.ReviewHandler.UpdateVisibility)
		}
	}

	return router
}
