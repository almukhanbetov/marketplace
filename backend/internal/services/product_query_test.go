package services

import (
	"testing"

	"github.com/nova/marketplace-backend/internal/models"
)

func TestParseProductQuery_Defaults(t *testing.T) {
	f, err := ParseProductQuery(ProductQueryParams{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.Limit != defaultLimit {
		t.Errorf("Limit = %d, want default %d", f.Limit, defaultLimit)
	}
	if f.Offset != defaultOffset {
		t.Errorf("Offset = %d, want default %d", f.Offset, defaultOffset)
	}
	if f.Sort != "" {
		t.Errorf("Sort = %q, want empty (repository applies its own default)", f.Sort)
	}
}

func TestParseProductQuery_ValidSort(t *testing.T) {
	for _, sort := range []string{"price_asc", "price_desc", "rating_desc", "newest", "discount_desc"} {
		f, err := ParseProductQuery(ProductQueryParams{Sort: sort})
		if err != nil {
			t.Errorf("sort=%q: unexpected error %v", sort, err)
		}
		if string(f.Sort) != sort {
			t.Errorf("sort=%q: got %q", sort, f.Sort)
		}
	}
}

func TestParseProductQuery_InvalidSort(t *testing.T) {
	_, err := ParseProductQuery(ProductQueryParams{Sort: "bogus_sort"})
	assertValidationError(t, err, "INVALID_SORT")
}

func TestParseProductQuery_InvalidRating(t *testing.T) {
	cases := []string{"9", "-1", "abc", "5.5.5"}
	for _, rating := range cases {
		_, err := ParseProductQuery(ProductQueryParams{Rating: rating})
		assertValidationError(t, err, "INVALID_RATING")
	}
}

func TestParseProductQuery_ValidRatingBoundaries(t *testing.T) {
	for _, rating := range []string{"0", "5", "4.5", "3"} {
		f, err := ParseProductQuery(ProductQueryParams{Rating: rating})
		if err != nil {
			t.Errorf("rating=%q: unexpected error %v", rating, err)
		}
		if f.MinRating != rating {
			t.Errorf("rating=%q: MinRating = %q", rating, f.MinRating)
		}
	}
}

func TestParseProductQuery_InvalidPrice(t *testing.T) {
	cases := map[string]string{
		"min_price": "abc",
		"max_price": "-100",
	}
	for field, val := range cases {
		var params ProductQueryParams
		if field == "min_price" {
			params.MinPrice = val
		} else {
			params.MaxPrice = val
		}
		_, err := ParseProductQuery(params)
		if err == nil {
			t.Errorf("%s=%q: expected validation error, got nil", field, val)
		}
	}
}

func TestParseProductQuery_ValidPrice(t *testing.T) {
	f, err := ParseProductQuery(ProductQueryParams{MinPrice: "100000", MaxPrice: "500000.50"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.MinPrice != "100000" || f.MaxPrice != "500000.50" {
		t.Errorf("got MinPrice=%q MaxPrice=%q", f.MinPrice, f.MaxPrice)
	}
}

func TestParseProductQuery_InvalidLimit(t *testing.T) {
	for _, limit := range []string{"-5", "0", "abc"} {
		_, err := ParseProductQuery(ProductQueryParams{Limit: limit})
		assertValidationError(t, err, "INVALID_LIMIT")
	}
}

func TestParseProductQuery_LimitClampedAboveMax(t *testing.T) {
	f, err := ParseProductQuery(ProductQueryParams{Limit: "500"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.Limit != maxLimit {
		t.Errorf("Limit = %d, want clamped to %d", f.Limit, maxLimit)
	}
}

func TestParseProductQuery_InvalidOffset(t *testing.T) {
	for _, offset := range []string{"-1", "abc"} {
		_, err := ParseProductQuery(ProductQueryParams{Offset: offset})
		assertValidationError(t, err, "INVALID_OFFSET")
	}
}

func TestParseProductQuery_SellerNumericBecomesID(t *testing.T) {
	f, err := ParseProductQuery(ProductQueryParams{Seller: "3"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.SellerID == nil || *f.SellerID != 3 {
		t.Errorf("expected SellerID=3, got %v (SellerSlug=%q)", f.SellerID, f.SellerSlug)
	}
	if f.SellerSlug != "" {
		t.Errorf("expected SellerSlug empty when seller is numeric, got %q", f.SellerSlug)
	}
}

func TestParseProductQuery_SellerSlugStaysSlug(t *testing.T) {
	f, err := ParseProductQuery(ProductQueryParams{Seller: "techstore"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if f.SellerSlug != "techstore" {
		t.Errorf("expected SellerSlug=techstore, got %q", f.SellerSlug)
	}
	if f.SellerID != nil {
		t.Errorf("expected SellerID nil for a slug seller value, got %v", *f.SellerID)
	}
}

func TestParseProductQuery_InvalidCategoryID(t *testing.T) {
	_, err := ParseProductQuery(ProductQueryParams{CategoryID: "not-a-number"})
	assertValidationError(t, err, "INVALID_CATEGORY_ID")
}

func assertValidationError(t *testing.T, err error, wantCode string) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected a validation error with code %s, got nil", wantCode)
	}
	ve, ok := err.(*models.ValidationError)
	if !ok {
		t.Fatalf("expected *models.ValidationError, got %T (%v)", err, err)
	}
	if ve.Code != wantCode {
		t.Errorf("error code = %q, want %q", ve.Code, wantCode)
	}
}
