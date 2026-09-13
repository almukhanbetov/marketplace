package models

import "time"

// AdminOrderUserSummary is the safe customer info shown to admins on an
// order — never password_hash.
type AdminOrderUserSummary struct {
	ID       int64   `json:"id"`
	FullName string  `json:"full_name"`
	Email    *string `json:"email"`
	Phone    *string `json:"phone"`
}

// AdminOrderListItem is one row of GET /admin/orders — marketplace-wide,
// unlike the customer-scoped order list.
type AdminOrderListItem struct {
	ID            int64                 `json:"id"`
	OrderNumber   string                `json:"order_number"`
	User          AdminOrderUserSummary `json:"user"`
	Status        OrderStatus           `json:"status"`
	ItemCount     int                   `json:"item_count"`
	SellerCount   int                   `json:"seller_count"`
	Total         Money                 `json:"total"`
	Currency      string                `json:"currency"`
	PaymentStatus string                `json:"payment_status"`
	CreatedAt     time.Time             `json:"created_at"`
}

// AdminOrderItemDetail is one line of an admin order detail — every
// seller's items are visible here, unlike the seller-scoped or
// customer-scoped views (Stage 8 §21: admin-only financial visibility).
type AdminOrderItemDetail struct {
	SellerID         int64  `json:"seller_id"`
	SellerName       string `json:"seller_name"`
	ProductID        *int64 `json:"product_id"`
	ProductName      string `json:"product_name"`
	SKU              string `json:"sku"`
	Quantity         int    `json:"quantity"`
	UnitPrice        Money  `json:"unit_price"`
	TotalPrice       Money  `json:"total_price"`
	CommissionAmount Money  `json:"commission_amount"`
	SellerAmount     Money  `json:"seller_amount"`
}

// AdminOrderDetail is GET /admin/orders/:id.
type AdminOrderDetail struct {
	ID              int64                  `json:"id"`
	OrderNumber     string                 `json:"order_number"`
	User            AdminOrderUserSummary  `json:"user"`
	Status          OrderStatus            `json:"status"`
	Delivery        DeliverySnapshot       `json:"delivery"`
	Items           []AdminOrderItemDetail `json:"items"`
	Subtotal        Money                  `json:"subtotal"`
	DeliveryTotal   Money                  `json:"delivery_total"`
	CommissionTotal Money                  `json:"commission_total"`
	Total           Money                  `json:"total"`
	Currency        string                 `json:"currency"`
	Payment         *OrderPaymentSummary   `json:"payment"`
	CreatedAt       time.Time              `json:"created_at"`
}

// AdminOrderQuery is the validated filter for AdminOrderRepository.List.
type AdminOrderQuery struct {
	Status   string
	UserID   *int64
	DateFrom string // "YYYY-MM-DD", "" = unset
	DateTo   string
	MinTotal string
	MaxTotal string
	Sort     string
	Limit    int
	Offset   int
}
