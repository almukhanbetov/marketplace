package models

import "time"

// AdminPayoutItem is one row of GET /admin/payouts — marketplace-wide,
// unlike the seller-scoped Payout list, and carries the seller's name for
// display.
type AdminPayoutItem struct {
	ID          int64        `json:"id"`
	SellerID    int64        `json:"seller_id"`
	SellerName  string       `json:"seller_name"`
	Amount      Money        `json:"amount"`
	Status      PayoutStatus `json:"status"`
	RequestedAt time.Time    `json:"requested_at"`
	ProcessedAt *time.Time   `json:"processed_at"`
}

// AdminPayoutQuery is the validated filter for AdminPayoutRepository.List.
type AdminPayoutQuery struct {
	Status string
	Limit  int
	Offset int
}

// PayoutTransitions is the single source of truth for which payout status
// transitions an admin may perform (Stage 8 §25/§26): pending can move to
// processing or rejected; processing can move to paid or rejected; paid
// and rejected are terminal. Never edited ad hoc elsewhere — every
// transition check goes through this map so the rule can't drift.
var PayoutTransitions = map[PayoutStatus][]PayoutStatus{
	PayoutStatusPending:    {PayoutStatusProcessing, PayoutStatusRejected},
	PayoutStatusProcessing: {PayoutStatusPaid, PayoutStatusRejected},
	PayoutStatusPaid:       {},
	PayoutStatusRejected:   {},
}

// IsValidPayoutTransition reports whether from -> to is an allowed
// transition per PayoutTransitions.
func IsValidPayoutTransition(from, to PayoutStatus) bool {
	for _, allowed := range PayoutTransitions[from] {
		if allowed == to {
			return true
		}
	}
	return false
}
