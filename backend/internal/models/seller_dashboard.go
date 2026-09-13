package models

import "time"

// LowStockThreshold is the single source of truth for "low stock" across
// every seller-dashboard endpoint (Stage 7 §10) — the backend always
// computes the IsLowStock flag itself; the frontend never hardcodes this
// number or recomputes the comparison.
const LowStockThreshold = 5

// SellerDashboardSummary is GET /sellers/:sellerId/dashboard.
//
// Metric definitions (Stage 7 §5, kept distinct on purpose):
//   - "sales"/gross = sum(order_items.total_price) — gross merchandise
//     value, what the customer paid for this seller's lines.
//   - "net" = sum(order_items.seller_amount) — gross minus commission,
//     what actually lands in this seller's balance.
//
// Both exclude order_items belonging to a 'cancelled' or 'returned' order.
type SellerDashboardSummary struct {
	SalesToday        Money   `json:"sales_today"`
	OrdersToday       int     `json:"orders_today"`
	OrdersTotal       int     `json:"orders_total"`
	PendingBalance    Money   `json:"pending_balance"`
	AvailableBalance  Money   `json:"available_balance"`
	ActiveOffers      int     `json:"active_offers"`
	LowStockOffers    int     `json:"low_stock_offers"`
	LowStockThreshold int     `json:"low_stock_threshold"`
	Rating            float64 `json:"rating"`
	ReviewCount       int     `json:"review_count"`
}

// SellerOfferItem is one row of GET /sellers/:sellerId/offers — the
// seller's own private view of their offer (unlike the public catalog's
// ProductCard, this is never filtered by "currently purchasable" — a
// seller must be able to see and reactivate their own inactive/out-of-
// stock offers).
type SellerOfferItem struct {
	ID                int64         `json:"id"`
	ProductID         int64         `json:"product_id"`
	ProductName       LocalizedText `json:"product_name"`
	Brand             string        `json:"brand"`
	PrimaryImage      *string       `json:"primary_image"`
	SKU               string        `json:"sku"`
	Price             Money         `json:"price"`
	OldPrice          *Money        `json:"old_price"`
	DeliveryDays      int           `json:"delivery_days"`
	IsActive          bool          `json:"is_active"`
	AvailableQuantity int           `json:"available_quantity"`
	ReservedQuantity  int           `json:"reserved_quantity"`
	IsLowStock        bool          `json:"is_low_stock"`
	CreatedAt         time.Time     `json:"created_at"`
	UpdatedAt         time.Time     `json:"updated_at"`
}

// SellerOfferQuery is the validated GET /offers query (Stage 7 §6).
type SellerOfferQuery struct {
	Search   string
	Status   string // "", "active", "inactive"
	LowStock bool
	Sort     string
	Limit    int
	Offset   int
}

// CreateOfferInput is POST /offers (Stage 7 §7) — a seller offer against an
// EXISTING catalog product, never a new product record (§35).
type CreateOfferInput struct {
	ProductID    int64
	SKU          string
	Price        string
	OldPrice     string // "" = none
	DeliveryDays int
	Stock        int
}

// UpdateOfferInput is PUT /offers/:offerId (Stage 7 §8) — sku/price/
// old_price/delivery_days only; seller_id/product_id are never
// reassignable through this endpoint.
type UpdateOfferInput struct {
	SKU          string
	Price        string
	OldPrice     string
	DeliveryDays int
}

// SellerInventoryItem is one row of GET /sellers/:sellerId/inventory.
type SellerInventoryItem struct {
	OfferID           int64         `json:"offer_id"`
	ProductID         int64         `json:"product_id"`
	ProductName       LocalizedText `json:"product_name"`
	SKU               string        `json:"sku"`
	AvailableQuantity int           `json:"available_quantity"`
	ReservedQuantity  int           `json:"reserved_quantity"`
	IsLowStock        bool          `json:"is_low_stock"`
	UpdatedAt         time.Time     `json:"updated_at"`
}
