package models

// Offer is one seller's public, purchasable listing of a product — the
// core marketplace fact that a product can have several of these, from
// different sellers, at different prices.
//
// "Purchasable" here always means the offer satisfies the public
// availability rule (see services.ProductService doc comment): the offer,
// its seller and its product are all active, and its inventory has
// available_quantity > 0. Callers never see offers that fail this rule.
type Offer struct {
	OfferID           int64   `json:"offer_id"`
	SellerID          int64   `json:"seller_id"`
	SellerName        string  `json:"seller_name"`
	SellerSlug        string  `json:"seller_slug"`
	SellerRating      float64 `json:"seller_rating"`
	SellerVerified    bool    `json:"seller_verified"`
	SKU               string  `json:"sku"`
	Price             Money   `json:"price"`
	OldPrice          *Money  `json:"old_price"`
	DiscountPercent   int     `json:"discount_percent"`
	DeliveryDays      int     `json:"delivery_days"`
	AvailableQuantity int     `json:"available_quantity"`
}
