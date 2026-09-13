package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// ReviewRepository covers both the public read-only reviews endpoint and
// admin moderation — consolidated because moderation IS the write path for
// the same rows the public endpoint reads (Stage 8 §38).
type ReviewRepository struct {
	pool *pgxpool.Pool
}

func NewReviewRepository(pool *pgxpool.Pool) *ReviewRepository {
	return &ReviewRepository{pool: pool}
}

// ListPublic returns only is_visible = TRUE reviews for one product, never
// exposing the reviewer's email/phone (Stage 8 §31/§32) — user_display_name
// is derived from full_name only.
func (r *ReviewRepository) ListPublic(ctx context.Context, productID int64, limit, offset int) ([]models.PublicReview, int, error) {
	var total int
	if err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM reviews WHERE product_id = $1 AND is_visible = TRUE`, productID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count public reviews for product %d: %w", productID, err)
	}
	if total == 0 {
		return []models.PublicReview{}, 0, nil
	}

	rows, err := r.pool.Query(ctx, `
		SELECT r.id, r.rating, COALESCE(r.text, ''), u.full_name, r.created_at
		FROM reviews r
		JOIN users u ON u.id = r.user_id
		WHERE r.product_id = $1 AND r.is_visible = TRUE
		ORDER BY r.created_at DESC, r.id DESC
		LIMIT $2 OFFSET $3
	`, productID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("query public reviews for product %d: %w", productID, err)
	}
	defer rows.Close()

	items := []models.PublicReview{}
	for rows.Next() {
		var it models.PublicReview
		if err := rows.Scan(&it.ID, &it.Rating, &it.Text, &it.UserDisplayName, &it.CreatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan public review: %w", err)
		}
		items = append(items, it)
	}
	return items, total, rows.Err()
}

func (r *ReviewRepository) ListAdmin(ctx context.Context, q models.AdminReviewQuery) ([]models.AdminReviewItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.ProductID != nil {
		conditions = append(conditions, "r.product_id = "+next(*q.ProductID))
	}
	if q.Rating != nil {
		conditions = append(conditions, "r.rating = "+next(*q.Rating))
	}
	if q.Visible == "true" {
		conditions = append(conditions, "r.is_visible = TRUE")
	} else if q.Visible == "false" {
		conditions = append(conditions, "r.is_visible = FALSE")
	}
	if q.UserID != nil {
		conditions = append(conditions, "r.user_id = "+next(*q.UserID))
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	countQuery := "SELECT COUNT(*) FROM reviews r WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin reviews: %w", err)
	}
	if total == 0 {
		return []models.AdminReviewItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT r.id, r.product_id, p.name_ru, r.user_id, u.full_name, r.rating, COALESCE(r.text, ''), r.is_visible, r.created_at
		FROM reviews r
		JOIN products p ON p.id = r.product_id
		JOIN users u ON u.id = r.user_id
		WHERE %s
		ORDER BY r.created_at DESC, r.id DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin reviews: %w", err)
	}
	defer rows.Close()

	items := []models.AdminReviewItem{}
	for rows.Next() {
		var it models.AdminReviewItem
		if err := rows.Scan(&it.ID, &it.ProductID, &it.ProductName, &it.UserID, &it.UserName, &it.Rating, &it.Text, &it.IsVisible, &it.CreatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan admin review: %w", err)
		}
		items = append(items, it)
	}
	return items, total, rows.Err()
}

func (r *ReviewRepository) GetByID(ctx context.Context, id int64) (*models.AdminReviewItem, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT r.id, r.product_id, p.name_ru, r.user_id, u.full_name, r.rating, COALESCE(r.text, ''), r.is_visible, r.created_at
		FROM reviews r
		JOIN products p ON p.id = r.product_id
		JOIN users u ON u.id = r.user_id
		WHERE r.id = $1
	`, id)
	var it models.AdminReviewItem
	err := row.Scan(&it.ID, &it.ProductID, &it.ProductName, &it.UserID, &it.UserName, &it.Rating, &it.Text, &it.IsVisible, &it.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin review %d: %w", id, err)
	}
	return &it, nil
}

// UpdateVisibility flips is_visible and recalculates the parent product's
// rating/review_count from its currently-visible reviews, in one
// transaction (Stage 8 §35/§36): AVG/COUNT over is_visible = TRUE rows,
// or exactly 0/0 if none remain — never left stale, never computed
// separately from the visibility change that caused it. Returns
// models.ErrNotFound if the review doesn't exist.
func (r *ReviewRepository) UpdateVisibility(ctx context.Context, id int64, isVisible bool) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin review visibility transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var productID int64
	tag, err := tx.Exec(ctx, `UPDATE reviews SET is_visible = $1, updated_at = NOW() WHERE id = $2`, isVisible, id)
	if err != nil {
		return fmt.Errorf("update review visibility %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	if err := tx.QueryRow(ctx, `SELECT product_id FROM reviews WHERE id = $1`, id).Scan(&productID); err != nil {
		return fmt.Errorf("find product for review %d: %w", id, err)
	}

	if _, err := tx.Exec(ctx, `
		UPDATE products SET
			rating = COALESCE((SELECT AVG(rating) FROM reviews WHERE product_id = $1 AND is_visible = TRUE), 0),
			review_count = COALESCE((SELECT COUNT(*) FROM reviews WHERE product_id = $1 AND is_visible = TRUE), 0),
			updated_at = NOW()
		WHERE id = $1
	`, productID); err != nil {
		return fmt.Errorf("recalculate product rating %d: %w", productID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit review visibility transaction: %w", err)
	}
	return nil
}
