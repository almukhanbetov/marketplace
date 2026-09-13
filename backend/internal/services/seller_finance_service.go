package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type SellerFinanceService struct {
	financeRepo *repositories.SellerFinanceRepository
	sellerRepo  *repositories.SellerRepository
}

func NewSellerFinanceService(financeRepo *repositories.SellerFinanceRepository, sellerRepo *repositories.SellerRepository) *SellerFinanceService {
	return &SellerFinanceService{financeRepo: financeRepo, sellerRepo: sellerRepo}
}

func (s *SellerFinanceService) GetSummary(ctx context.Context, sellerID int64) (*models.SellerFinanceSummary, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	return s.financeRepo.GetSummary(ctx, sellerID)
}
