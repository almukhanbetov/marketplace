package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type CategoryService struct {
	repo *repositories.CategoryRepository
}

func NewCategoryService(repo *repositories.CategoryRepository) *CategoryService {
	return &CategoryService{repo: repo}
}

// List returns every active category, root and child.
func (s *CategoryService) List(ctx context.Context) ([]models.Category, error) {
	return s.repo.ListActive(ctx)
}

// GetByID returns one active category, or models.ErrNotFound if it doesn't
// exist (or is inactive — inactive categories are not publicly visible).
func (s *CategoryService) GetByID(ctx context.Context, id int64) (*models.Category, error) {
	return s.repo.GetByID(ctx, id)
}
