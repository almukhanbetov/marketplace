package models

// CreateCategoryInput is the validated POST /admin/categories body.
type CreateCategoryInput struct {
	ParentID  *int64
	NameRU    string
	NameKK    string
	NameEN    string
	Slug      string
	ImageURL  string
	SortOrder int
	IsActive  bool
}

// UpdateCategoryInput is the validated PUT /admin/categories/:id body.
type UpdateCategoryInput struct {
	ParentID  *int64
	NameRU    string
	NameKK    string
	NameEN    string
	Slug      string
	ImageURL  string
	SortOrder int
}
