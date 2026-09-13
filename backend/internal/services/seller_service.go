package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// SellerProductsResult bundles a page of a seller's products with the total
// count, for meta.total. Limit/Offset are the validated, applied values.
type SellerProductsResult struct {
	Items  []models.SellerProductItem
	Total  int
	Limit  int
	Offset int
}

type SellerService struct {
	repo *repositories.SellerRepository
}

func NewSellerService(repo *repositories.SellerRepository) *SellerService {
	return &SellerService{repo: repo}
}

// List returns every active seller.
func (s *SellerService) List(ctx context.Context) ([]models.SellerCard, error) {
	return s.repo.ListActive(ctx)
}

// GetByID returns one active seller's public profile, or models.ErrNotFound.
func (s *SellerService) GetByID(ctx context.Context, id int64) (*models.SellerDetail, error) {
	return s.repo.GetByID(ctx, id)
}

// ListProducts returns a validated page of the products this seller
// currently has a valid offer for, priced at the seller's own offer.
// Confirms the seller exists first so an unknown seller id is a 404, not an
// empty 200 page.
func (s *SellerService) ListProducts(ctx context.Context, sellerID int64, rawLimit, rawOffset string) (SellerProductsResult, error) {
	exists, err := s.repo.Exists(ctx, sellerID)
	if err != nil {
		return SellerProductsResult{}, err
	}
	if !exists {
		return SellerProductsResult{}, models.ErrNotFound
	}

	limit, offset, err := parsePagination(rawLimit, rawOffset)
	if err != nil {
		return SellerProductsResult{}, err
	}

	items, total, err := s.repo.ListProducts(ctx, sellerID, limit, offset)
	if err != nil {
		return SellerProductsResult{}, err
	}

	return SellerProductsResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}
