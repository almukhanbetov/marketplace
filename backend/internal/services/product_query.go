package services

import (
	"regexp"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
)

// ProductQueryParams are the *raw* query string values a handler extracted
// from gin.Context — plain strings, no parsing or validation applied yet.
// Handlers build this by simple extraction only; every decision about
// whether a value is acceptable happens in ParseProductQuery below (Stage 3
// §24/§32: raw query strings never reach the repository, and validation is
// a service responsibility).
type ProductQueryParams struct {
	Search     string
	Category   string
	CategoryID string
	Seller     string
	Brand      string
	MinPrice   string
	MaxPrice   string
	Rating     string
	Sort       string
	Limit      string
	Offset     string
}

const (
	defaultLimit  = 20
	maxLimit      = 100
	defaultOffset = 0
)

var (
	// decimalPattern accepts a non-negative amount with up to 2 decimal
	// places — the same shape NUMERIC(14,2) columns store, so it can be
	// bound straight into a "$n::numeric" comparison with no float64
	// parsing anywhere in this path (Stage 3 §18/§28).
	decimalPattern = regexp.MustCompile(`^[0-9]+(\.[0-9]{1,2})?$`)
)

var validSorts = map[string]models.SortOption{
	string(models.SortPriceAsc):     models.SortPriceAsc,
	string(models.SortPriceDesc):    models.SortPriceDesc,
	string(models.SortRatingDesc):   models.SortRatingDesc,
	string(models.SortNewest):       models.SortNewest,
	string(models.SortDiscountDesc): models.SortDiscountDesc,
}

// ParseProductQuery validates raw query params into a models.ProductFilter,
// or returns a *models.ValidationError describing exactly what was wrong
// (mapped to 400 by the handler). Every rule here matches Stage 3 §20/§23/
// §31: unknown sort, out-of-range rating, non-numeric price, and invalid
// pagination are all rejected rather than silently ignored or clamped.
func ParseProductQuery(p ProductQueryParams) (models.ProductFilter, error) {
	f := models.ProductFilter{
		Search:       strings.TrimSpace(p.Search),
		CategorySlug: strings.TrimSpace(p.Category),
		Brand:        strings.TrimSpace(p.Brand),
	}

	if p.CategoryID != "" {
		id, err := strconv.ParseInt(p.CategoryID, 10, 64)
		if err != nil || id <= 0 {
			return f, models.NewValidationError("INVALID_CATEGORY_ID", "category_id must be a positive integer")
		}
		f.CategoryID = &id
	}

	if seller := strings.TrimSpace(p.Seller); seller != "" {
		if id, err := strconv.ParseInt(seller, 10, 64); err == nil && id > 0 {
			f.SellerID = &id
		} else {
			f.SellerSlug = seller
		}
	}

	minPrice, err := parseDecimalParam(p.MinPrice, "min_price")
	if err != nil {
		return f, err
	}
	f.MinPrice = minPrice

	maxPrice, err := parseDecimalParam(p.MaxPrice, "max_price")
	if err != nil {
		return f, err
	}
	f.MaxPrice = maxPrice

	rating, err := parseRatingParam(p.Rating)
	if err != nil {
		return f, err
	}
	f.MinRating = rating

	sort, err := parseSortParam(p.Sort)
	if err != nil {
		return f, err
	}
	f.Sort = sort

	limit, offset, err := parsePagination(p.Limit, p.Offset)
	if err != nil {
		return f, err
	}
	f.Limit = limit
	f.Offset = offset

	return f, nil
}

func parseDecimalParam(raw, field string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", nil
	}
	if !decimalPattern.MatchString(raw) {
		return "", models.NewValidationError(
			"INVALID_"+strings.ToUpper(field),
			field+" must be a non-negative decimal amount, e.g. \"100000\" or \"100000.50\"",
		)
	}
	return raw, nil
}

func parseRatingParam(raw string) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", nil
	}
	if !decimalPattern.MatchString(raw) {
		return "", models.NewValidationError("INVALID_RATING", "rating must be a number between 0 and 5")
	}
	value, err := strconv.ParseFloat(raw, 64)
	if err != nil || value < 0 || value > 5 {
		return "", models.NewValidationError("INVALID_RATING", "rating must be between 0 and 5")
	}
	return raw, nil
}

func parseSortParam(raw string) (models.SortOption, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", nil
	}
	sort, ok := validSorts[raw]
	if !ok {
		return "", models.NewValidationError("INVALID_SORT", "sort must be one of: price_asc, price_desc, rating_desc, newest, discount_desc")
	}
	return sort, nil
}

func parsePagination(rawLimit, rawOffset string) (int, int, error) {
	limit := defaultLimit
	if rawLimit = strings.TrimSpace(rawLimit); rawLimit != "" {
		v, err := strconv.Atoi(rawLimit)
		if err != nil || v <= 0 {
			return 0, 0, models.NewValidationError("INVALID_LIMIT", "limit must be a positive integer")
		}
		if v > maxLimit {
			v = maxLimit // clamp above the max rather than reject (Stage 3 §23)
		}
		limit = v
	}

	offset := defaultOffset
	if rawOffset = strings.TrimSpace(rawOffset); rawOffset != "" {
		v, err := strconv.Atoi(rawOffset)
		if err != nil || v < 0 {
			return 0, 0, models.NewValidationError("INVALID_OFFSET", "offset must be zero or a positive integer")
		}
		offset = v
	}

	return limit, offset, nil
}
