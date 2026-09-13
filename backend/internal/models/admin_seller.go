package models

import "time"

// AdminSellerListItem is one row of GET /admin/sellers.
type AdminSellerListItem struct {
	ID               int64     `json:"id"`
	UserID           int64     `json:"user_id"`
	Name             string    `json:"name"`
	Slug             string    `json:"slug"`
	Rating           float64   `json:"rating"`
	ReviewCount      int       `json:"review_count"`
	IsVerified       bool      `json:"is_verified"`
	IsActive         bool      `json:"is_active"`
	ActiveOfferCount int       `json:"active_offer_count"`
	CreatedAt        time.Time `json:"created_at"`
}

// AdminSellerDetail is GET /admin/sellers/:id — public seller data plus the
// safe account/financial summary an admin needs. Never includes the linked
// user's password_hash.
type AdminSellerDetail struct {
	ID          int64     `json:"id"`
	UserID      int64     `json:"user_id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description string    `json:"description"`
	Rating      float64   `json:"rating"`
	ReviewCount int       `json:"review_count"`
	IsVerified  bool      `json:"is_verified"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`

	AccountEmail    *string `json:"account_email"`
	AccountPhone    *string `json:"account_phone"`
	AccountIsActive bool    `json:"account_is_active"`

	TotalOfferCount  int `json:"total_offer_count"`
	ActiveOfferCount int `json:"active_offer_count"`
	LowStockOffers   int `json:"low_stock_offers"`

	OrderCount          int   `json:"order_count"`
	GrossSales          Money `json:"gross_sales"`
	CommissionGenerated Money `json:"commission_generated"`
	PendingBalance      Money `json:"pending_balance"`
	AvailableBalance    Money `json:"available_balance"`
	PayoutCount         int   `json:"payout_count"`
}

// AdminSellerQuery is the validated filter for AdminSellerRepository.List.
type AdminSellerQuery struct {
	Search   string
	Verified *bool
	Status   string // "", "active", "inactive"
	Sort     string
	Limit    int
	Offset   int
}
