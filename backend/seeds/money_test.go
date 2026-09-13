package seeds

import "testing"

func TestParseCentsAndFormatCents_RoundTrip(t *testing.T) {
	cases := []string{"620000.00", "0.00", "19500.50", "1150000.99", "42000.05"}
	for _, amount := range cases {
		cents := parseCents(amount)
		back := formatCents(cents)
		if back != amount {
			t.Errorf("round trip mismatch: parseCents(%q)=%d, formatCents(...)=%q", amount, cents, back)
		}
	}
}

func TestParseCents(t *testing.T) {
	cases := map[string]int64{
		"620000.00": 62000000,
		"98000.00":  9800000,
		"19500.50":  1950050,
		"0.00":      0,
	}
	for amount, want := range cases {
		if got := parseCents(amount); got != want {
			t.Errorf("parseCents(%q) = %d, want %d", amount, got, want)
		}
	}
}

func TestScaleMoney_NoFloatRoundingSurprises(t *testing.T) {
	// 620000.00 * 1.03 = 638600.00 exactly; scaleMoney rounds to the
	// nearest 100 KZT, so this should land exactly on that value.
	got := scaleMoney("620000.00", 1.03)
	want := "638600.00"
	if got != want {
		t.Errorf("scaleMoney(620000.00, 1.03) = %q, want %q", got, want)
	}
}

func TestScaleMoney_AlwaysTwoDecimals(t *testing.T) {
	got := scaleMoney("19500.00", 0.97)
	if len(got) < 3 || got[len(got)-3] != '.' {
		t.Errorf("scaleMoney result %q does not look like a 2-decimal amount", got)
	}
}

func TestRatingToStars(t *testing.T) {
	cases := map[string]int{
		"4.30": 4,
		"4.85": 5, // rounds up at .50+
		"4.49": 4,
		"0.90": 1, // clamped to minimum 1
		"5.20": 5, // clamped to maximum 5
	}
	for rating, want := range cases {
		if got := ratingToStars(rating); got != want {
			t.Errorf("ratingToStars(%q) = %d, want %d", rating, got, want)
		}
	}
}

func TestSeedDataShape(t *testing.T) {
	if len(users) < 3 {
		t.Errorf("expected at least 3 seed users, got %d", len(users))
	}
	if len(sellers) < 3 {
		t.Errorf("expected at least 3 seed sellers, got %d", len(sellers))
	}
	if len(categories) < 10 {
		t.Errorf("expected at least 10 seed categories, got %d", len(categories))
	}
	if len(products) < 30 {
		t.Errorf("expected at least 30 seed products, got %d", len(products))
	}

	sellerSlugs := make(map[string]bool, len(sellers))
	for _, s := range sellers {
		sellerSlugs[s.Slug] = true
	}
	for _, p := range products {
		if !sellerSlugs[p.PrimarySellerSlug] {
			t.Errorf("product %s references unknown primary seller %s", p.Slug, p.PrimarySellerSlug)
		}
	}
}

func TestPlanOffersForProduct_MultiSellerCoverage(t *testing.T) {
	multiSellerCount := 0
	totalOffers := 0

	for i, p := range products {
		plans := planOffersForProduct(i, p)
		totalOffers += len(plans)

		distinct := map[string]bool{}
		for _, plan := range plans {
			distinct[plan.sellerSlug] = true
		}
		if len(distinct) > 1 {
			multiSellerCount++
		}
	}

	if totalOffers < 45 {
		t.Errorf("expected at least 45 total planned seller offers, got %d", totalOffers)
	}
	if multiSellerCount == 0 {
		t.Error("expected at least one product with offers from multiple sellers")
	}
}
