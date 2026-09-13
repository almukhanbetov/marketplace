package models

// Cart is the demo user's cart (Stage 5 — one cart per user, no order
// reservation yet). ID is nil until the user's first item is added; the
// row is created lazily rather than at account creation.
type Cart struct {
	ID      *int64      `json:"id"`
	UserID  int64       `json:"user_id"`
	Items   []CartItem  `json:"items"`
	Summary CartSummary `json:"summary"`
}

// CartItem is priced from the seller_offer's CURRENT price, read fresh from
// the database on every request — never trusted from the client (Stage 5
// §12). Unlike the public catalog's product cards, a cart item is still
// returned even when its offer/seller/product has since gone inactive or
// its inventory has dropped to zero, so the frontend can show the item as
// unavailable rather than have it silently vanish (§13) — this is a
// deliberately different visibility rule from the catalog's valid_offers
// CTE, not an inconsistency with it.
type CartItem struct {
	ID                int64           `json:"id"`
	Quantity          int             `json:"quantity"`
	SellerOfferID     int64           `json:"seller_offer_id"`
	Product           CartItemProduct `json:"product"`
	Seller            CartItemSeller  `json:"seller"`
	Price             Money           `json:"price"`
	OldPrice          *Money          `json:"old_price"`
	DeliveryDays      int             `json:"delivery_days"`
	AvailableQuantity int             `json:"available_quantity"`
	IsAvailable       bool            `json:"is_available"`
	LineTotal         Money           `json:"line_total"`
}

type CartItemProduct struct {
	ID           int64         `json:"id"`
	Brand        string        `json:"brand"`
	Name         LocalizedText `json:"name"`
	PrimaryImage *string       `json:"primary_image"`
}

type CartItemSeller struct {
	ID     int64   `json:"id"`
	Name   string  `json:"name"`
	Rating float64 `json:"rating"`
}

// CartSummary carries only backend-authoritative totals; discount/shipping
// display math stays a frontend concern (it already has that logic and it
// isn't specific to any one order — Stage 6 owns real order totals).
type CartSummary struct {
	ItemCount int   `json:"item_count"`
	Subtotal  Money `json:"subtotal"`
}
