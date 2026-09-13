package models

import "time"

// PayoutStatus mirrors the payouts.status CHECK constraint. Stage 7 only
// ever produces "pending" (§26) — processing/paid/rejected are set by a
// later settlement stage, not implemented yet.
type PayoutStatus string

const (
	PayoutStatusPending    PayoutStatus = "pending"
	PayoutStatusProcessing PayoutStatus = "processing"
	PayoutStatusPaid       PayoutStatus = "paid"
	PayoutStatusRejected   PayoutStatus = "rejected"
)

// Payout is one row of GET /sellers/:sellerId/payouts.
type Payout struct {
	ID          int64        `json:"id"`
	Amount      Money        `json:"amount"`
	Status      PayoutStatus `json:"status"`
	RequestedAt time.Time    `json:"requested_at"`
	ProcessedAt *time.Time   `json:"processed_at"`
}

// CreatePayoutInput is POST /sellers/:sellerId/payouts.
type CreatePayoutInput struct {
	Amount         string
	IdempotencyKey string
}
