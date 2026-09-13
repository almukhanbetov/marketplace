package services

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/money"
)

// DefaultCommissionRate is the single source of truth for the marketplace's
// cut of every order item (Stage 6 §11) — a NUMERIC(5,4)-shaped string
// matching commissions.rate/order_items.commission_rate's column type
// exactly. Every commission calculation in the codebase goes through
// commissionSplit below; nothing else hardcodes 10%.
const DefaultCommissionRate = "0.1000"

// defaultCommissionBasisPoints is DefaultCommissionRate expressed as parts
// per 10000, so commissionSplit can compute in exact integer arithmetic —
// never float64 (Stage 6 §12).
const defaultCommissionBasisPoints = 1000

// commissionSplit computes (commission, sellerAmount) for one order item's
// total price, guaranteeing commission + sellerAmount == totalPrice exactly
// (Stage 6 §48): sellerAmount is derived by subtraction from the total,
// never rounded independently, so the two can never drift apart by a cent.
func commissionSplit(totalPrice string) (commission, sellerAmount string) {
	totalCents := money.ToCents(totalPrice)
	commissionCents := totalCents * defaultCommissionBasisPoints / 10000
	sellerCents := totalCents - commissionCents
	return money.FromCents(commissionCents), money.FromCents(sellerCents)
}

// parsePositiveMoney is a defensive guard used where a decimal string is
// about to be persisted — Stage 6 never trusts a computed string blindly
// into SQL without at least shape-checking it once.
func parsePositiveMoney(s string) error {
	whole, frac, found := strings.Cut(s, ".")
	if !found || len(frac) != 2 {
		return fmt.Errorf("malformed money value %q", s)
	}
	if _, err := strconv.ParseInt(whole, 10, 64); err != nil {
		return fmt.Errorf("malformed money value %q: %w", s, err)
	}
	if _, err := strconv.ParseInt(frac, 10, 64); err != nil {
		return fmt.Errorf("malformed money value %q: %w", s, err)
	}
	return nil
}
