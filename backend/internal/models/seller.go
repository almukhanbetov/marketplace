package models

// SellerCard is one item in the public sellers list. It never exposes the
// underlying user's email/phone or any financial data (balances,
// commissions, payouts) — those belong to the seller-dashboard/admin APIs
// of a later stage, not the public catalog.
type SellerCard struct {
	ID               int64   `json:"id"`
	Name             string  `json:"name"`
	Slug             string  `json:"slug"`
	Description      string  `json:"description"`
	Rating           float64 `json:"rating"`
	ReviewCount      int     `json:"review_count"`
	IsVerified       bool    `json:"is_verified"`
	ActiveOfferCount int     `json:"active_offer_count"`
}

// SellerDetail is the public seller profile page payload.
type SellerDetail struct {
	ID               int64   `json:"id"`
	Name             string  `json:"name"`
	Slug             string  `json:"slug"`
	Description      string  `json:"description"`
	Rating           float64 `json:"rating"`
	ReviewCount      int     `json:"review_count"`
	IsVerified       bool    `json:"is_verified"`
	IsActive         bool    `json:"is_active"`
	ProductCount     int     `json:"product_count"`
	ActiveOfferCount int     `json:"active_offer_count"`
}

// SellerProductItem is one row of GET /sellers/:id/products — unlike
// ProductCard, the price here is always THIS seller's own offer, never the
// marketplace-wide cheapest offer from a different seller.
type SellerProductItem struct {
	ProductID         int64         `json:"product_id"`
	Slug              string        `json:"slug"`
	Name              LocalizedText `json:"name"`
	Brand             string        `json:"brand"`
	Rating            float64       `json:"rating"`
	ReviewCount       int           `json:"review_count"`
	PrimaryImage      *string       `json:"primary_image"`
	OfferID           int64         `json:"offer_id"`
	SKU               string        `json:"sku"`
	Price             Money         `json:"price"`
	OldPrice          *Money        `json:"old_price"`
	DiscountPercent   int           `json:"discount_percent"`
	DeliveryDays      int           `json:"delivery_days"`
	AvailableQuantity int           `json:"available_quantity"`
}
