package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// requireSeller is shared by every Stage 7 seller-scoped service — the
// :sellerId path param is development-only (no auth yet), but every
// resource lookup still validates it names a real, active seller before
// doing anything else (Stage 7 §2/§29).
func requireSeller(ctx context.Context, repo *repositories.SellerRepository, sellerID int64) error {
	exists, err := repo.Exists(ctx, sellerID)
	if err != nil {
		return err
	}
	if !exists {
		return models.NewNotFoundError("SELLER_NOT_FOUND", "Seller not found")
	}
	return nil
}

type SellerDashboardService struct {
	dashboardRepo *repositories.SellerDashboardRepository
	sellerRepo    *repositories.SellerRepository
}

func NewSellerDashboardService(dashboardRepo *repositories.SellerDashboardRepository, sellerRepo *repositories.SellerRepository) *SellerDashboardService {
	return &SellerDashboardService{dashboardRepo: dashboardRepo, sellerRepo: sellerRepo}
}

func (s *SellerDashboardService) GetSummary(ctx context.Context, sellerID int64) (*models.SellerDashboardSummary, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	return s.dashboardRepo.GetSummary(ctx, sellerID)
}
