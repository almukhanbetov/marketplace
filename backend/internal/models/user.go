package models

import "time"

// User is the admin-safe view of a users row — password_hash is never
// included in this type at all (not just omitted from JSON), so there is
// no field to accidentally serialize (Stage 8 §6/§71).
type User struct {
	ID        int64     `json:"id"`
	Email     *string   `json:"email"`
	Phone     *string   `json:"phone"`
	FullName  string    `json:"full_name"`
	Role      string    `json:"role"`
	IsActive  bool      `json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// UserDetail extends User with admin-useful aggregates. SellerID is nil
// unless this user account owns a seller (role="seller" with a matching
// sellers.user_id row).
type UserDetail struct {
	User
	OrdersCount    int    `json:"orders_count"`
	FavoritesCount int    `json:"favorites_count"`
	AddressesCount int    `json:"addresses_count"`
	SellerID       *int64 `json:"seller_id"`
}

// UserQuery is the validated, typed filter AdminUserRepository.List runs —
// built once in the service layer from raw query strings (Stage 8 §41).
type UserQuery struct {
	Search string
	Role   string // "", "customer", "seller", "admin"
	Status string // "", "active", "inactive"
	Sort   string
	Limit  int
	Offset int
}
