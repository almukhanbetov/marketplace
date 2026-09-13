package models

import "time"

// OrderStatus mirrors the orders.status CHECK constraint. Stage 6 only
// ever produces "new" (briefly, mid-transaction) then "paid" (mock payment
// always succeeds) — the rest exist for later stages.
type OrderStatus string

const (
	OrderStatusNew        OrderStatus = "new"
	OrderStatusConfirmed  OrderStatus = "confirmed"
	OrderStatusPaid       OrderStatus = "paid"
	OrderStatusProcessing OrderStatus = "processing"
	OrderStatusShipped    OrderStatus = "shipped"
	OrderStatusDelivered  OrderStatus = "delivered"
	OrderStatusCancelled  OrderStatus = "cancelled"
	OrderStatusReturned   OrderStatus = "returned"
)

// PaymentProvider mirrors the payments.provider CHECK constraint — the
// only four mock providers Stage 6 accepts (Stage 6 §4/§46).
type PaymentProvider string

const (
	PaymentProviderCard          PaymentProvider = "card"
	PaymentProviderKaspiMock     PaymentProvider = "kaspi_mock"
	PaymentProviderApplePayMock  PaymentProvider = "apple_pay_mock"
	PaymentProviderGooglePayMock PaymentProvider = "google_pay_mock"
)

var ValidPaymentProviders = map[PaymentProvider]bool{
	PaymentProviderCard:          true,
	PaymentProviderKaspiMock:     true,
	PaymentProviderApplePayMock:  true,
	PaymentProviderGooglePayMock: true,
}

// DeliverySnapshot is the address as it existed at order-creation time,
// copied so a later address edit/delete never rewrites history (Stage 6
// §26/§27).
type DeliverySnapshot struct {
	Title      *string `json:"title"`
	City       string  `json:"city"`
	Street     string  `json:"street"`
	House      string  `json:"house"`
	Apartment  *string `json:"apartment"`
	PostalCode *string `json:"postal_code"`
}

// OrderItemPreview is the compact per-line shape used in the order list
// response — enough for a thumbnail + "N items" summary, no N+1 (Stage 6
// §30).
type OrderItemPreview struct {
	ProductName  string  `json:"product_name"`
	PrimaryImage *string `json:"primary_image"`
	Quantity     int     `json:"quantity"`
}

// OrderSummary is one row of GET /users/:userId/orders.
type OrderSummary struct {
	ID           int64              `json:"id"`
	OrderNumber  string             `json:"order_number"`
	Status       OrderStatus        `json:"status"`
	Total        Money              `json:"total"`
	Currency     string             `json:"currency"`
	ItemCount    int                `json:"item_count"`
	CreatedAt    time.Time          `json:"created_at"`
	ItemsPreview []OrderItemPreview `json:"items_preview"`
}

// OrderItemDetail is one line of GET /users/:userId/orders/:id — customer-
// facing only: no commission_rate/commission_amount/seller_amount (Stage 6
// §31/§32, that belongs to a seller/admin API, not implemented in Stage 6).
type OrderItemDetail struct {
	ProductID    *int64  `json:"product_id"`
	ProductName  string  `json:"product_name"`
	PrimaryImage *string `json:"primary_image"`
	SellerName   string  `json:"seller_name"`
	Quantity     int     `json:"quantity"`
	UnitPrice    Money   `json:"unit_price"`
	TotalPrice   Money   `json:"total_price"`
}

// OrderPaymentSummary is the customer-facing payment status — no internal
// external_reference exposed beyond what's useful to show "how you paid".
type OrderPaymentSummary struct {
	Provider PaymentProvider `json:"provider"`
	Status   string          `json:"status"`
}

// OrderDetail is the full GET /users/:userId/orders/:id payload.
type OrderDetail struct {
	ID            int64                `json:"id"`
	OrderNumber   string               `json:"order_number"`
	Status        OrderStatus          `json:"status"`
	CreatedAt     time.Time            `json:"created_at"`
	Delivery      DeliverySnapshot     `json:"delivery"`
	Payment       *OrderPaymentSummary `json:"payment"`
	Subtotal      Money                `json:"subtotal"`
	DiscountTotal Money                `json:"discount_total"`
	DeliveryTotal Money                `json:"delivery_total"`
	Total         Money                `json:"total"`
	Currency      string               `json:"currency"`
	Items         []OrderItemDetail    `json:"items"`
}

// CreateOrderInput is the validated request to create an order — only user
// choices, never prices (Stage 6 §3).
type CreateOrderInput struct {
	AddressID       int64
	PaymentProvider PaymentProvider
	IdempotencyKey  string
}
