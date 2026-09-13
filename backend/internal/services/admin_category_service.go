package services

import (
	"context"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminCategoryService struct {
	repo *repositories.AdminCategoryRepository
}

func NewAdminCategoryService(repo *repositories.AdminCategoryRepository) *AdminCategoryService {
	return &AdminCategoryService{repo: repo}
}

func (s *AdminCategoryService) ListAll(ctx context.Context) ([]models.Category, error) {
	return s.repo.ListAll(ctx)
}

func validateCategoryFields(nameRU, nameKK, nameEN, slug string) error {
	if strings.TrimSpace(nameRU) == "" || strings.TrimSpace(nameKK) == "" || strings.TrimSpace(nameEN) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "name_ru, name_kk and name_en are all required")
	}
	if strings.TrimSpace(slug) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "slug is required")
	}
	return nil
}

// validateParent guards against the two obvious invalid hierarchies Stage
// 8 §18 calls out — self-parenting, and a 2-level cycle (A's parent is B,
// B's parent is set to A) — without a full graph traversal. selfID is 0
// for a brand-new category (nothing to self-reference yet).
func (s *AdminCategoryService) validateParent(ctx context.Context, selfID int64, parentID *int64) error {
	if parentID == nil {
		return nil
	}
	if selfID != 0 && *parentID == selfID {
		return models.NewValidationError("INVALID_PARENT", "a category cannot be its own parent")
	}
	parent, err := s.repo.GetByID(ctx, *parentID)
	if err != nil {
		if err == models.ErrNotFound {
			return models.NewNotFoundError("CATEGORY_NOT_FOUND", "Parent category not found")
		}
		return err
	}
	if selfID != 0 && parent.ParentID != nil && *parent.ParentID == selfID {
		return models.NewValidationError("INVALID_PARENT", "this would create a cycle: the chosen parent's own parent is this category")
	}
	return nil
}

func (s *AdminCategoryService) Create(ctx context.Context, in models.CreateCategoryInput) (int64, error) {
	if err := validateCategoryFields(in.NameRU, in.NameKK, in.NameEN, in.Slug); err != nil {
		return 0, err
	}
	if err := s.validateParent(ctx, 0, in.ParentID); err != nil {
		return 0, err
	}
	id, err := s.repo.Create(ctx, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return 0, models.NewConflictError("SLUG_ALREADY_EXISTS", "A category with this slug already exists")
		}
		return 0, err
	}
	return id, nil
}

func (s *AdminCategoryService) Update(ctx context.Context, id int64, in models.UpdateCategoryInput) error {
	if err := validateCategoryFields(in.NameRU, in.NameKK, in.NameEN, in.Slug); err != nil {
		return err
	}
	if err := s.validateParent(ctx, id, in.ParentID); err != nil {
		return err
	}
	err := s.repo.Update(ctx, id, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return models.NewConflictError("SLUG_ALREADY_EXISTS", "A category with this slug already exists")
		}
		return err
	}
	return nil
}

// UpdateStatus flips is_active — categories are never physically deleted
// because products may still reference them (Stage 8 §19).
func (s *AdminCategoryService) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	return s.repo.UpdateStatus(ctx, id, isActive)
}
