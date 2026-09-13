// Package services holds business rules that sit between HTTP handlers and
// repositories: query validation, the marketplace's "public availability"
// and "best offer" rules, and not-found handling. Nothing here knows about
// Gin or SQL.
package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// ProductListResult bundles a page of products with the total count of all
// matching products (ignoring pagination), for meta.total. Limit/Offset are
// the *validated, applied* values (after defaulting/clamping), so the
// handler can echo back what was actually used.
type ProductListResult struct {
	Items  []models.ProductCard
	Total  int
	Limit  int
	Offset int
}

type ProductService struct {
	repo *repositories.ProductRepository
}

func NewProductService(repo *repositories.ProductRepository) *ProductService {
	return &ProductService{repo: repo}
}

// List validates raw query params and returns the matching product page.
//
// Public availability rule (Stage 3 §7, centralized in
// repositories.validOffersCTE): a product only appears here if it has at
// least one offer where the offer, its seller, and the product itself are
// all active, and its inventory has available_quantity > 0. A product with
// zero such offers is excluded from this list entirely (§41) — it may
// still exist and be reachable via GetByID for its own detail page.
//
// Best offer rule (§27, centralized in repositories.bestOfferRankedCTE):
// each returned product is priced at its cheapest valid offer, ties broken
// by higher seller rating then lower offer id.
func (s *ProductService) List(ctx context.Context, raw ProductQueryParams) (ProductListResult, error) {
	filter, err := ParseProductQuery(raw)
	if err != nil {
		return ProductListResult{}, err
	}

	items, total, err := s.repo.List(ctx, filter)
	if err != nil {
		return ProductListResult{}, err
	}

	return ProductListResult{Items: items, Total: total, Limit: filter.Limit, Offset: filter.Offset}, nil
}

// GetByID returns full product detail, or models.ErrNotFound.
func (s *ProductService) GetByID(ctx context.Context, id int64) (*models.ProductDetail, error) {
	return s.repo.GetByID(ctx, id)
}

// ListOffers returns every valid offer for a product. It first confirms the
// product exists so callers can tell "unknown product" (404) apart from
// "real product, currently zero purchasable offers" (200, empty list) —
// both would otherwise look identical to the repository query alone.
func (s *ProductService) ListOffers(ctx context.Context, productID int64) ([]models.Offer, error) {
	exists, err := s.repo.Exists(ctx, productID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, models.ErrNotFound
	}
	return s.repo.ListOffers(ctx, productID)
}
