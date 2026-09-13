package models

import "time"

// AdminProductListItem is one row of GET /admin/products — admin sees
// every product regardless of is_active (unlike the public catalog).
type AdminProductListItem struct {
	ID           int64         `json:"id"`
	Slug         string        `json:"slug"`
	Brand        string        `json:"brand"`
	Name         LocalizedText `json:"name"`
	Category     CategoryRef   `json:"category"`
	Rating       float64       `json:"rating"`
	ReviewCount  int           `json:"review_count"`
	PrimaryImage *string       `json:"primary_image"`
	OfferCount   int           `json:"offer_count"`
	IsActive     bool          `json:"is_active"`
	CreatedAt    time.Time     `json:"created_at"`
}

// AdminProductImage is one product_images row.
type AdminProductImage struct {
	ID        int64  `json:"id"`
	URL       string `json:"url"`
	IsPrimary bool   `json:"is_primary"`
	SortOrder int    `json:"sort_order"`
}

// AdminProductDetail is GET /admin/products/:id.
type AdminProductDetail struct {
	ID          int64               `json:"id"`
	Slug        string              `json:"slug"`
	Brand       string              `json:"brand"`
	Name        LocalizedText       `json:"name"`
	Description LocalizedText       `json:"description"`
	Category    CategoryRef         `json:"category"`
	Rating      float64             `json:"rating"`
	ReviewCount int                 `json:"review_count"`
	Images      []AdminProductImage `json:"images"`
	OfferCount  int                 `json:"offer_count"`
	IsActive    bool                `json:"is_active"`
	CreatedAt   time.Time           `json:"created_at"`
	UpdatedAt   time.Time           `json:"updated_at"`
}

// ProductImageInput is one image in a create/update product request —
// URL-based only, no file upload (Stage 8 §17).
type ProductImageInput struct {
	URL       string
	IsPrimary bool
	SortOrder int
}

// CreateProductInput is the validated POST /admin/products body. Admin
// manages global catalog identity only — never a seller-specific
// price/stock (those belong to seller_offers, Stage 8 §13/§53).
type CreateProductInput struct {
	CategoryID    int64
	Brand         string
	NameRU        string
	NameKK        string
	NameEN        string
	DescriptionRU string
	DescriptionKK string
	DescriptionEN string
	Slug          string
	IsActive      bool
	Images        []ProductImageInput
}

// UpdateProductInput is the validated PUT /admin/products/:id body.
type UpdateProductInput struct {
	CategoryID    int64
	Brand         string
	NameRU        string
	NameKK        string
	NameEN        string
	DescriptionRU string
	DescriptionKK string
	DescriptionEN string
	Slug          string
	IsActive      bool
	Images        []ProductImageInput
}

// AdminProductQuery is the validated filter for AdminProductRepository.List.
type AdminProductQuery struct {
	Search     string
	CategoryID *int64
	Status     string // "", "active", "inactive"
	Sort       string
	Limit      int
	Offset     int
}
