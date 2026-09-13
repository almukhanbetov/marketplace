package services

import (
	"context"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminProductService struct {
	repo         *repositories.AdminProductRepository
	categoryRepo *repositories.AdminCategoryRepository
}

func NewAdminProductService(repo *repositories.AdminProductRepository, categoryRepo *repositories.AdminCategoryRepository) *AdminProductService {
	return &AdminProductService{repo: repo, categoryRepo: categoryRepo}
}

type AdminProductListResult struct {
	Items  []models.AdminProductListItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminProductQuery struct {
	Search     string
	CategoryID string
	Status     string
	Sort       string
	Limit      string
	Offset     string
}

var validAdminProductSorts = map[string]bool{"": true, "created_at_asc": true, "created_at_desc": true, "name_asc": true}

func (s *AdminProductService) List(ctx context.Context, raw RawAdminProductQuery) (AdminProductListResult, error) {
	status := strings.TrimSpace(raw.Status)
	if !validStatusFilters[status] {
		return AdminProductListResult{}, models.NewValidationError("INVALID_STATUS", "status must be one of: active, inactive")
	}
	sort := strings.TrimSpace(raw.Sort)
	if !validAdminProductSorts[sort] {
		return AdminProductListResult{}, models.NewValidationError("INVALID_SORT", "sort must be one of: created_at_asc, created_at_desc, name_asc")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminProductListResult{}, err
	}

	var categoryID *int64
	if raw.CategoryID != "" {
		id, parseErr := strconv.ParseInt(raw.CategoryID, 10, 64)
		if parseErr != nil || id <= 0 {
			return AdminProductListResult{}, models.NewValidationError("INVALID_CATEGORY_ID", "category_id must be a positive integer")
		}
		categoryID = &id
	}

	items, total, err := s.repo.List(ctx, models.AdminProductQuery{
		Search: strings.TrimSpace(raw.Search), CategoryID: categoryID, Status: status, Sort: sort, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminProductListResult{}, err
	}
	return AdminProductListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *AdminProductService) GetDetail(ctx context.Context, id int64) (*models.AdminProductDetail, error) {
	return s.repo.GetByID(ctx, id)
}

// validateProductFields is shared by Create and Update: names/slug
// required, category must exist. Never validates price/stock — those
// belong to seller offers, not the global product (Stage 8 §13/§53).
func (s *AdminProductService) validateProductFields(ctx context.Context, categoryID int64, nameRU, nameKK, nameEN, slug string, images []models.ProductImageInput) error {
	if categoryID <= 0 {
		return models.NewValidationError("VALIDATION_ERROR", "category_id is required")
	}
	if strings.TrimSpace(nameRU) == "" || strings.TrimSpace(nameKK) == "" || strings.TrimSpace(nameEN) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "name_ru, name_kk and name_en are all required")
	}
	if strings.TrimSpace(slug) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "slug is required")
	}
	for _, img := range images {
		if strings.TrimSpace(img.URL) == "" {
			return models.NewValidationError("VALIDATION_ERROR", "every image must have a non-empty url")
		}
	}
	if _, err := s.categoryRepo.GetByID(ctx, categoryID); err != nil {
		if err == models.ErrNotFound {
			return models.NewNotFoundError("CATEGORY_NOT_FOUND", "Category not found")
		}
		return err
	}
	return nil
}

// Create inserts a new global product + images. Never creates a
// seller_offer — a product may exist before any seller lists it (Stage 8
// §14).
func (s *AdminProductService) Create(ctx context.Context, in models.CreateProductInput) (int64, error) {
	if err := s.validateProductFields(ctx, in.CategoryID, in.NameRU, in.NameKK, in.NameEN, in.Slug, in.Images); err != nil {
		return 0, err
	}
	id, err := s.repo.Create(ctx, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return 0, models.NewConflictError("SLUG_ALREADY_EXISTS", "A product with this slug already exists")
		}
		return 0, err
	}
	return id, nil
}

func (s *AdminProductService) Update(ctx context.Context, id int64, in models.UpdateProductInput) error {
	if err := s.validateProductFields(ctx, in.CategoryID, in.NameRU, in.NameKK, in.NameEN, in.Slug, in.Images); err != nil {
		return err
	}
	err := s.repo.Update(ctx, id, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return models.NewConflictError("SLUG_ALREADY_EXISTS", "A product with this slug already exists")
		}
		return err
	}
	return nil
}

// UpdateStatus flips is_active. An inactive product disappears from the
// public catalog (Stage 3's existing is_active rule); historical order
// items keep their own snapshot regardless (Stage 8 §16).
func (s *AdminProductService) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	return s.repo.UpdateStatus(ctx, id, isActive)
}
