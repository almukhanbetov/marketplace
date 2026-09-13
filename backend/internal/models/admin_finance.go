package models

import "time"

// AdminPaymentItem is one row of GET /admin/payments — read-only, no real
// gateway actions (Stage 8 §23). "Mock" providers are labeled as such by
// their own provider value (kaspi_mock, apple_pay_mock, ...).
type AdminPaymentItem struct {
	ID                int64     `json:"id"`
	OrderID           int64     `json:"order_id"`
	Provider          string    `json:"provider"`
	Status            string    `json:"status"`
	Amount            Money     `json:"amount"`
	Currency          string    `json:"currency"`
	ExternalReference *string   `json:"external_reference"`
	CreatedAt         time.Time `json:"created_at"`
}

// AdminPaymentQuery is the validated filter for AdminFinanceRepository.ListPayments.
type AdminPaymentQuery struct {
	Status   string
	Provider string
	DateFrom string
	DateTo   string
	Limit    int
	Offset   int
}

// AdminCommissionItem is one row of GET /admin/commissions.
type AdminCommissionItem struct {
	ID          int64     `json:"id"`
	OrderItemID int64     `json:"order_item_id"`
	OrderID     int64     `json:"order_id"`
	SellerID    int64     `json:"seller_id"`
	SellerName  string    `json:"seller_name"`
	Rate        string    `json:"rate"`
	Amount      Money     `json:"amount"`
	CreatedAt   time.Time `json:"created_at"`
}

// AdminCommissionQuery is the validated filter for AdminFinanceRepository.ListCommissions.
type AdminCommissionQuery struct {
	SellerID *int64
	DateFrom string
	DateTo   string
	Limit    int
	Offset   int
}
