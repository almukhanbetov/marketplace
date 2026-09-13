// Package models holds the marketplace read-model types shared by the
// repository, service and handler layers: what a category/product/seller
// looks like once assembled from the database, ready to serialize as JSON.
//
// These are deliberately data-only — no SQL, no HTTP, no validation logic.
package models

// Money is a decimal amount serialized as an exact JSON string (e.g.
// "620000.00"), never a JSON number. NUMERIC(14,2) columns are always
// fetched from PostgreSQL with an explicit ::text cast in the repository
// layer and land here unchanged, so no float64 ever touches a monetary
// value anywhere in the request path.
type Money string

// LocalizedText carries the three languages the frontend supports (RU/KK/EN).
type LocalizedText struct {
	RU string `json:"ru"`
	KK string `json:"kk"`
	EN string `json:"en"`
}
