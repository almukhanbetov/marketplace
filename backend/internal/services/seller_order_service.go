package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type SellerOrderService struct {
	orderRepo  *repositories.SellerOrderRepository
	sellerRepo *repositories.SellerRepository
}

func NewSellerOrderService(orderRepo *repositories.SellerOrderRepository, sellerRepo *repositories.SellerRepository) *SellerOrderService {
	return &SellerOrderService{orderRepo: orderRepo, sellerRepo: sellerRepo}
}

type SellerOrderListResult struct {
	Items  []models.SellerOrderSummary
	Total  int
	Limit  int
	Offset int
}

func (s *SellerOrderService) List(ctx context.Context, sellerID int64, rawLimit, rawOffset string) (SellerOrderListResult, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return SellerOrderListResult{}, err
	}
	limit, offset, err := parsePagination(rawLimit, rawOffset)
	if err != nil {
		return SellerOrderListResult{}, err
	}
	items, total, err := s.orderRepo.List(ctx, sellerID, limit, offset)
	if err != nil {
		return SellerOrderListResult{}, err
	}
	return SellerOrderListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *SellerOrderService) GetDetail(ctx context.Context, sellerID, orderID int64) (*models.SellerOrderDetail, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	return s.orderRepo.GetDetail(ctx, sellerID, orderID)
}
