package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminOverviewService struct {
	repo *repositories.AdminOverviewRepository
}

func NewAdminOverviewService(repo *repositories.AdminOverviewRepository) *AdminOverviewService {
	return &AdminOverviewService{repo: repo}
}

func (s *AdminOverviewService) GetSummary(ctx context.Context) (*models.AdminOverviewSummary, error) {
	return s.repo.GetSummary(ctx)
}
