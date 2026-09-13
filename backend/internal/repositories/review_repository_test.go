package repositories_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/testutil"
)

// reviewTestProductID is dedicated to this test — no other Stage 5/6/7/8
// test touches the reviews table at all, so any product is safe to use;
// this one is picked arbitrarily (iPhone 17 Pro 256GB, product 1).
const reviewTestProductID = int64(1)

// withCleanReviews replaces every review on reviewTestProductID with none,
// runs fn, then restores the product's original reviews and its original
// rating/review_count exactly — mirroring the save-and-restore rigor
// established by Stage 6/7's balance/inventory tests.
func withCleanReviews(t *testing.T, pool *pgxpool.Pool, fn func(ctx context.Context)) {
	t.Helper()
	ctx := context.Background()

	type savedReview struct {
		userID int64
		rating int
		text   string
	}
	var saved []savedReview
	rows, err := pool.Query(ctx, `SELECT user_id, rating, COALESCE(text, '') FROM reviews WHERE product_id = $1`, reviewTestProductID)
	if err != nil {
		t.Fatalf("save existing reviews: %v", err)
	}
	for rows.Next() {
		var sr savedReview
		if err := rows.Scan(&sr.userID, &sr.rating, &sr.text); err != nil {
			t.Fatalf("scan existing review: %v", err)
		}
		saved = append(saved, sr)
	}
	rows.Close()

	var origRating, origCount string
	if err := pool.QueryRow(ctx, `SELECT rating::text, review_count::text FROM products WHERE id = $1`, reviewTestProductID).Scan(&origRating, &origCount); err != nil {
		t.Fatalf("save original product rating: %v", err)
	}

	t.Cleanup(func() {
		ctx := context.Background()
		if _, err := pool.Exec(ctx, `DELETE FROM reviews WHERE product_id = $1`, reviewTestProductID); err != nil {
			t.Errorf("cleanup: delete test reviews: %v", err)
		}
		for _, sr := range saved {
			if _, err := pool.Exec(ctx, `INSERT INTO reviews (product_id, user_id, rating, text, is_visible) VALUES ($1, $2, $3, $4, TRUE)`,
				reviewTestProductID, sr.userID, sr.rating, sr.text); err != nil {
				t.Errorf("cleanup: restore review for user %d: %v", sr.userID, err)
			}
		}
		if _, err := pool.Exec(ctx, `UPDATE products SET rating = $1, review_count = $2 WHERE id = $3`, origRating, origCount, reviewTestProductID); err != nil {
			t.Errorf("cleanup: restore product rating: %v", err)
		}
	})

	if _, err := pool.Exec(ctx, `DELETE FROM reviews WHERE product_id = $1`, reviewTestProductID); err != nil {
		t.Fatalf("clear existing reviews: %v", err)
	}

	fn(ctx)
}

// TestReviewRepository_UpdateVisibility_RecalculatesProductRating is the
// exact example from Stage 8 §69: three visible reviews (5, 4, 3) average
// to rating=4, count=3. Hiding the rating-3 review recalculates to
// rating=4.5, count=2. Showing it again recalculates back to rating=4,
// count=3 — proving the aggregate is derived fresh each time, never
// drifting.
func TestReviewRepository_UpdateVisibility_RecalculatesProductRating(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewReviewRepository(pool)

	withCleanReviews(t, pool, func(ctx context.Context) {
		// Seeded customers 10/11/12 — reviews has UNIQUE(user_id, product_id)
		// so three distinct reviewers are needed for three reviews.
		var review5ID, review4ID, review3ID int64
		insert := func(userID int64, rating int) int64 {
			var id int64
			if err := pool.QueryRow(ctx, `INSERT INTO reviews (product_id, user_id, rating, is_visible) VALUES ($1, $2, $3, TRUE) RETURNING id`,
				reviewTestProductID, userID, rating).Scan(&id); err != nil {
				t.Fatalf("insert review (user %d, rating %d): %v", userID, rating, err)
			}
			return id
		}
		review5ID = insert(10, 5)
		review4ID = insert(11, 4)
		review3ID = insert(12, 3)
		_ = review4ID

		// Force an initial recompute (is_visible unchanged, but
		// UpdateVisibility always recalculates) to establish the 4/3
		// baseline from a clean product row that may not yet reflect these
		// brand-new inserts.
		if err := repo.UpdateVisibility(ctx, review5ID, true); err != nil {
			t.Fatalf("baseline recompute error = %v", err)
		}
		assertProductRating(t, pool, "4.00", 3, "after seeding 5/4/3")

		if err := repo.UpdateVisibility(ctx, review3ID, false); err != nil {
			t.Fatalf("hide rating-3 review error = %v", err)
		}
		assertProductRating(t, pool, "4.50", 2, "after hiding the rating-3 review")

		publicReviews, total, err := repo.ListPublic(ctx, reviewTestProductID, 20, 0)
		if err != nil {
			t.Fatalf("ListPublic() error = %v", err)
		}
		if total != 2 {
			t.Errorf("ListPublic() total = %d, want 2 (hidden review excluded)", total)
		}
		for _, r := range publicReviews {
			if r.ID == review3ID {
				t.Error("ListPublic() returned the hidden review")
			}
		}

		if err := repo.UpdateVisibility(ctx, review3ID, true); err != nil {
			t.Fatalf("show rating-3 review again error = %v", err)
		}
		assertProductRating(t, pool, "4.00", 3, "after showing the rating-3 review again")
	})
}

func assertProductRating(t *testing.T, pool *pgxpool.Pool, wantRating string, wantCount int, when string) {
	t.Helper()
	var rating string
	var count int
	if err := pool.QueryRow(context.Background(), `SELECT rating::text, review_count FROM products WHERE id = $1`, reviewTestProductID).Scan(&rating, &count); err != nil {
		t.Fatalf("read product rating %s: %v", when, err)
	}
	if rating != wantRating || count != wantCount {
		t.Errorf("%s: rating=%s count=%d, want rating=%s count=%d", when, rating, count, wantRating, wantCount)
	}
}

// TestReviewRepository_UpdateVisibility_ZeroVisibleReviews covers Stage 8
// §35: hiding the only review on a product must reset rating/review_count
// to exactly 0, not leave a stale average.
func TestReviewRepository_UpdateVisibility_ZeroVisibleReviews(t *testing.T) {
	pool := testutil.ConnectTestDB(t)
	repo := repositories.NewReviewRepository(pool)

	withCleanReviews(t, pool, func(ctx context.Context) {
		var reviewID int64
		if err := pool.QueryRow(ctx, `INSERT INTO reviews (product_id, user_id, rating, is_visible) VALUES ($1, $2, $3, TRUE) RETURNING id`,
			reviewTestProductID, 10, 5).Scan(&reviewID); err != nil {
			t.Fatalf("insert review: %v", err)
		}

		if err := repo.UpdateVisibility(ctx, reviewID, false); err != nil {
			t.Fatalf("hide only review error = %v", err)
		}
		assertProductRating(t, pool, "0.00", 0, "after hiding the only review")
	})
}
