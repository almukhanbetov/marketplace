package repositories

import "github.com/nova/marketplace-backend/internal/money"

// Thin aliases onto the shared internal/money package (Stage 6 moved the
// actual implementation there so internal/services could reuse it too,
// without services depending on repositories for pure math — Stage 6
// §12). Kept here so the existing call sites in this package didn't need
// touching.
func moneyToCents(s string) int64                { return money.ToCents(s) }
func centsToMoney(cents int64) string            { return money.FromCents(cents) }
func multiplyMoney(price string, qty int) string { return money.Multiply(price, qty) }
