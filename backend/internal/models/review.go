package models

import "time"

// PublicReview is GET /products/:id/reviews' item shape — only visible
// reviews ever reach here, and never a user's email/phone (Stage 8 §31/§32).
type PublicReview struct {
	ID              int64     `json:"id"`
	Rating          int       `json:"rating"`
	Text            string    `json:"text"`
	UserDisplayName string    `json:"user_display_name"`
	CreatedAt       time.Time `json:"created_at"`
}

// AdminReviewItem is one row of GET /admin/reviews — every review
// regardless of visibility, with enough product/user context to moderate.
type AdminReviewItem struct {
	ID          int64     `json:"id"`
	ProductID   int64     `json:"product_id"`
	ProductName string    `json:"product_name"`
	UserID      int64     `json:"user_id"`
	UserName    string    `json:"user_name"`
	Rating      int       `json:"rating"`
	Text        string    `json:"text"`
	IsVisible   bool      `json:"is_visible"`
	CreatedAt   time.Time `json:"created_at"`
}

// AdminReviewQuery is the validated filter for ReviewRepository.ListAdmin.
type AdminReviewQuery struct {
	ProductID *int64
	Rating    *int
	Visible   string // "", "true", "false"
	UserID    *int64
	Sort      string
	Limit     int
	Offset    int
}
