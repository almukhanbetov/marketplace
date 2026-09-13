// Package money provides exact decimal-string arithmetic for NUMERIC(14,2)
// values fetched from PostgreSQL with an explicit ::text cast. Every money
// computation in the codebase — cart totals (Stage 5), order/commission
// totals (Stage 6) — goes through here so float64 never touches a
// monetary value anywhere in the request path (Stage 1 §18).
package money

import (
	"fmt"
	"strconv"
	"strings"
)

// ToCents converts a "620000.00"-shaped decimal string into integer cents.
func ToCents(s string) int64 {
	whole, frac, _ := strings.Cut(s, ".")
	w, _ := strconv.ParseInt(whole, 10, 64)
	frac = (frac + "00")[:2]
	f, _ := strconv.ParseInt(frac, 10, 64)
	return w*100 + f
}

// FromCents formats integer cents back into a "620000.00"-shaped string.
func FromCents(cents int64) string {
	return fmt.Sprintf("%d.%02d", cents/100, cents%100)
}

// Multiply computes price * qty exactly.
func Multiply(price string, qty int) string {
	return FromCents(ToCents(price) * int64(qty))
}

// Sum adds any number of decimal-string amounts exactly.
func Sum(values ...string) string {
	var total int64
	for _, v := range values {
		total += ToCents(v)
	}
	return FromCents(total)
}
