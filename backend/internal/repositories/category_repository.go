// Package repositories is the only layer that writes SQL. Every query is
// parameterized ($1, $2, ...); no user-supplied value is ever concatenated
// into a query string. No repository method takes a gin.Context — only
// context.Context, so DB calls respect request cancellation.
package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// CategoryRepository reads the categories table.
type CategoryRepository struct {
	pool *pgxpool.Pool
}

func NewCategoryRepository(pool *pgxpool.Pool) *CategoryRepository {
	return &CategoryRepository{pool: pool}
}

const categorySelectColumns = `
	c.id, c.parent_id, c.slug, c.name_ru, c.name_kk, c.name_en, c.image_url, c.sort_order, c.is_active,
	(SELECT COUNT(*) FROM categories child WHERE child.parent_id = c.id) AS child_count
`

// ListActive returns every active category (root and child), sorted by
// sort_order then id, per the Stage 3 spec.
func (r *CategoryRepository) ListActive(ctx context.Context) ([]models.Category, error) {
	query := fmt.Sprintf(`
		SELECT %s
		FROM categories c
		WHERE c.is_active = TRUE
		ORDER BY c.sort_order ASC, c.id ASC
	`, categorySelectColumns)

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}
	defer rows.Close()

	var categories []models.Category
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, fmt.Errorf("scan category: %w", err)
		}
		categories = append(categories, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate categories: %w", err)
	}

	return categories, nil
}

// GetByID returns a single active category, or models.ErrNotFound.
func (r *CategoryRepository) GetByID(ctx context.Context, id int64) (*models.Category, error) {
	query := fmt.Sprintf(`
		SELECT %s
		FROM categories c
		WHERE c.id = $1 AND c.is_active = TRUE
	`, categorySelectColumns)

	row := r.pool.QueryRow(ctx, query, id)
	c, err := scanCategory(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan category %d: %w", id, err)
	}
	return &c, nil
}

// rowScanner is satisfied by both pgx.Row and pgx.Rows.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanCategory(row rowScanner) (models.Category, error) {
	var c models.Category
	err := row.Scan(
		&c.ID, &c.ParentID, &c.Slug, &c.Name.RU, &c.Name.KK, &c.Name.EN,
		&c.ImageURL, &c.SortOrder, &c.IsActive, &c.ChildCount,
	)
	return c, err
}
