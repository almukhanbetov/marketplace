package models

// Address is one of a user's saved delivery addresses.
type Address struct {
	ID         int64   `json:"id"`
	UserID     int64   `json:"user_id"`
	Title      *string `json:"title"`
	City       string  `json:"city"`
	Street     string  `json:"street"`
	House      string  `json:"house"`
	Apartment  *string `json:"apartment"`
	PostalCode *string `json:"postal_code"`
	IsDefault  bool    `json:"is_default"`
}

// AddressInput is the validated write-shape shared by create and update —
// City/Street/House are required (Stage 5 §18); Title/Apartment/PostalCode
// are optional and stored as NULL when blank.
type AddressInput struct {
	Title      string
	City       string
	Street     string
	House      string
	Apartment  string
	PostalCode string
	IsDefault  bool
}
