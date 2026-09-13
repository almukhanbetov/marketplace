package models

// Category is a public catalog category, root or child (parent_id set).
type Category struct {
	ID         int64         `json:"id"`
	ParentID   *int64        `json:"parent_id"`
	Slug       string        `json:"slug"`
	Name       LocalizedText `json:"name"`
	ImageURL   *string       `json:"image_url"`
	SortOrder  int           `json:"sort_order"`
	IsActive   bool          `json:"is_active"`
	ChildCount int           `json:"child_count"`
}

// CategoryRef is the compact category reference embedded in product
// responses — just enough to link to/label the category, not the full
// Category shape.
type CategoryRef struct {
	ID   int64         `json:"id"`
	Slug string        `json:"slug"`
	Name LocalizedText `json:"name"`
}
