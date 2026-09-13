package models

import "time"

// SellerOrderSummary is one row of GET /sellers/:sellerId/orders —
// seller-scoped totals for a customer order that contains at least one of
// this seller's lines. Stage 7 §16/§17: orders are read-only from the
// seller side — there is no per-seller fulfillment/suborder entity yet
// (see the doc comment on SellerOrderRepository), so the seller sees the
// order's existing global status but cannot change it.
type SellerOrderSummary struct {
	OrderID                int64       `json:"order_id"`
	OrderNumber            string      `json:"order_number"`
	Status                 OrderStatus `json:"status"`
	CreatedAt              time.Time   `json:"created_at"`
	SellerItemCount        int         `json:"seller_item_count"`
	SellerGrossAmount      Money       `json:"seller_gross_amount"`
	SellerCommissionAmount Money       `json:"seller_commission_amount"`
	SellerNetAmount        Money       `json:"seller_net_amount"`
}

// SellerOrderItemDetail is one of THIS seller's lines within an order —
// other sellers' lines on the same multi-seller order are never included.
type SellerOrderItemDetail struct {
	ProductID        *int64 `json:"product_id"`
	ProductName      string `json:"product_name"`
	SKU              string `json:"sku"`
	Quantity         int    `json:"quantity"`
	UnitPrice        Money  `json:"unit_price"`
	TotalPrice       Money  `json:"total_price"`
	CommissionAmount Money  `json:"commission_amount"`
	SellerAmount     Money  `json:"seller_amount"`
}

// SellerOrderDetail is GET /sellers/:sellerId/orders/:orderId. Delivery is
// included because a seller genuinely needs it to ship (§15) — it is the
// same address snapshot the customer's own order detail shows, not
// additional customer PII (checkout never collects a separate name/phone
// today, see Stage 6).
type SellerOrderDetail struct {
	OrderID                int64                   `json:"order_id"`
	OrderNumber            string                  `json:"order_number"`
	Status                 OrderStatus             `json:"status"`
	CreatedAt              time.Time               `json:"created_at"`
	Delivery               DeliverySnapshot        `json:"delivery"`
	Items                  []SellerOrderItemDetail `json:"items"`
	SellerGrossAmount      Money                   `json:"seller_gross_amount"`
	SellerCommissionAmount Money                   `json:"seller_commission_amount"`
	SellerNetAmount        Money                   `json:"seller_net_amount"`
}

// SellerFinanceSummary is GET /sellers/:sellerId/finance (Stage 7 §18).
// gross_sales - commission_total == seller_net_total always (§19); pending/
// available mirror seller_balances directly (Stage 6 §22 semantics
// unchanged — Stage 7 never auto-moves pending to available).
type SellerFinanceSummary struct {
	GrossSales       Money `json:"gross_sales"`
	CommissionTotal  Money `json:"commission_total"`
	SellerNetTotal   Money `json:"seller_net_total"`
	PendingBalance   Money `json:"pending_balance"`
	AvailableBalance Money `json:"available_balance"`
	PaidOutTotal     Money `json:"paid_out_total"`
}
