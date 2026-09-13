package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// AdminCategoryRepository manages every category regardless of is_active —
// unlike the public CategoryRepository, which only ever lists active ones.
type AdminCategoryRepository struct {
	pool *pgxpool.Pool
}

func NewAdminCategoryRepository(pool *pgxpool.Pool) *AdminCategoryRepository {
	return &AdminCategoryRepository{pool: pool}
}

// ListAll returns every category (active and inactive), root and child.
func (r *AdminCategoryRepository) ListAll(ctx context.Context) ([]models.Category, error) {
	query := fmt.Sprintf(`
		SELECT %s
		FROM categories c
		ORDER BY c.sort_order ASC, c.id ASC
	`, categorySelectColumns)

	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("query admin categories: %w", err)
	}
	defer rows.Close()

	categories := []models.Category{}
	for rows.Next() {
		c, err := scanCategory(rows)
		if err != nil {
			return nil, fmt.Errorf("scan admin category: %w", err)
		}
		categories = append(categories, c)
	}
	return categories, rows.Err()
}

// GetByID returns any category (active or inactive) — unlike the public
// CategoryRepository.GetByID, which excludes inactive ones.
func (r *AdminCategoryRepository) GetByID(ctx context.Context, id int64) (*models.Category, error) {
	query := fmt.Sprintf(`SELECT %s FROM categories c WHERE c.id = $1`, categorySelectColumns)
	row := r.pool.QueryRow(ctx, query, id)
	c, err := scanCategory(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin category %d: %w", id, err)
	}
	return &c, nil
}

func (r *AdminCategoryRepository) Create(ctx context.Context, in models.CreateCategoryInput) (int64, error) {
	var id int64
	err := r.pool.QueryRow(ctx, `
		INSERT INTO categories (parent_id, name_ru, name_kk, name_en, slug, image_url, sort_order, is_active)
		VALUES ($1, $2, $3, $4, $5, NULLIF($6, ''), $7, $8)
		RETURNING id
	`, in.ParentID, in.NameRU, in.NameKK, in.NameEN, in.Slug, in.ImageURL, in.SortOrder, in.IsActive).Scan(&id)
	if err != nil {
		return 0, err
	}
	return id, nil
}

// Update edits a category's fields. Returns models.ErrNotFound if the
// category doesn't exist.
func (r *AdminCategoryRepository) Update(ctx context.Context, id int64, in models.UpdateCategoryInput) error {
	tag, err := r.pool.Exec(ctx, `
		UPDATE categories SET
			parent_id = $1, name_ru = $2, name_kk = $3, name_en = $4,
			slug = $5, image_url = NULLIF($6, ''), sort_order = $7, updated_at = NOW()
		WHERE id = $8
	`, in.ParentID, in.NameRU, in.NameKK, in.NameEN, in.Slug, in.ImageURL, in.SortOrder, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}

// UpdateStatus flips is_active — categories are never physically deleted
// because products may still reference them (Stage 8 §19).
func (r *AdminCategoryRepository) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	tag, err := r.pool.Exec(ctx, `UPDATE categories SET is_active = $1, updated_at = NOW() WHERE id = $2`, isActive, id)
	if err != nil {
		return fmt.Errorf("update category status %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}

// ParentDepth returns the parent_id of the given category, or nil if it
// has none / doesn't exist — used by the service to guard against an
// obvious 2-level cycle (A's parent is B, B's parent would become A)
// without a full graph traversal (Stage 8 §18).
func (r *AdminCategoryRepository) ParentOf(ctx context.Context, id int64) (*int64, error) {
	var parentID *int64
	err := r.pool.QueryRow(ctx, `SELECT parent_id FROM categories WHERE id = $1`, id).Scan(&parentID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("query parent of category %d: %w", id, err)
	}
	return parentID, nil
}
