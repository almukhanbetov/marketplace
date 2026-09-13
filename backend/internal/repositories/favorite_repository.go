package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type FavoriteRepository struct {
	pool *pgxpool.Pool
}

func NewFavoriteRepository(pool *pgxpool.Pool) *FavoriteRepository {
	return &FavoriteRepository{pool: pool}
}

// List returns the user's favorited products as full product cards — the
// exact same shape, best-offer pricing and availability rule as the public
// catalog (Stage 5 §4), reusing productCardSelect/productFromJoins/
// scanProductCard rather than a second, divergent projection. A favorited
// product that currently has zero valid offers is excluded, matching the
// catalog's own visibility rule (Stage 3 §41) — favoriting doesn't grant a
// product special visibility it wouldn't otherwise have.
func (r *FavoriteRepository) List(ctx context.Context, userID int64) ([]models.ProductCard, error) {
	cte := "WITH " + validOffersCTE + ", " + bestOfferRankedCTE + ", " + offerAggCTE

	query := fmt.Sprintf(`
		%s
		SELECT %s
		%s
		JOIN favorites f ON f.product_id = p.id
		WHERE p.is_active = TRUE AND f.user_id = $1
		ORDER BY f.created_at DESC
	`, cte, productCardSelect, productFromJoins)

	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("query favorites for user %d: %w", userID, err)
	}
	defer rows.Close()

	items := []models.ProductCard{}
	for rows.Next() {
		pc, err := scanProductCard(rows)
		if err != nil {
			return nil, fmt.Errorf("scan favorite product card: %w", err)
		}
		items = append(items, pc)
	}
	return items, rows.Err()
}

// Add inserts a favorite, or does nothing if it already exists (Stage 5
// §5: idempotent, no duplicate rows — the (user_id, product_id) primary
// key already guarantees this at the DB level, ON CONFLICT just avoids an
// error).
func (r *FavoriteRepository) Add(ctx context.Context, userID, productID int64) error {
	_, err := r.pool.Exec(ctx, `
		INSERT INTO favorites (user_id, product_id)
		VALUES ($1, $2)
		ON CONFLICT (user_id, product_id) DO NOTHING
	`, userID, productID)
	if err != nil {
		return fmt.Errorf("add favorite user=%d product=%d: %w", userID, productID, err)
	}
	return nil
}

// Remove deletes a favorite. Idempotent — no error if it was already absent
// (Stage 5 §6).
func (r *FavoriteRepository) Remove(ctx context.Context, userID, productID int64) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM favorites WHERE user_id = $1 AND product_id = $2`, userID, productID)
	if err != nil {
		return fmt.Errorf("remove favorite user=%d product=%d: %w", userID, productID, err)
	}
	return nil
}
