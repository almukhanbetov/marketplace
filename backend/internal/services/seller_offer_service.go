package services

import (
	"context"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type SellerOfferService struct {
	offerRepo   *repositories.SellerOfferRepository
	sellerRepo  *repositories.SellerRepository
	productRepo *repositories.ProductRepository
}

func NewSellerOfferService(offerRepo *repositories.SellerOfferRepository, sellerRepo *repositories.SellerRepository, productRepo *repositories.ProductRepository) *SellerOfferService {
	return &SellerOfferService{offerRepo: offerRepo, sellerRepo: sellerRepo, productRepo: productRepo}
}

// SellerOfferListResult bundles a page of offers with the total count, for
// meta.total (matching the public catalog's pagination convention).
type SellerOfferListResult struct {
	Items  []models.SellerOfferItem
	Total  int
	Limit  int
	Offset int
}

// RawSellerOfferQuery is what the handler extracts from gin.Context — raw
// strings, no validation performed yet (matching the product-list
// convention: validation is a service responsibility, Stage 3 §24/§32).
type RawSellerOfferQuery struct {
	Search   string
	Status   string
	LowStock string
	Sort     string
	Limit    string
	Offset   string
}

func (s *SellerOfferService) List(ctx context.Context, sellerID int64, raw RawSellerOfferQuery) (SellerOfferListResult, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return SellerOfferListResult{}, err
	}

	status := strings.TrimSpace(raw.Status)
	if status != "" && status != "active" && status != "inactive" {
		return SellerOfferListResult{}, models.NewValidationError("INVALID_STATUS", "status must be one of: active, inactive")
	}

	sort := strings.TrimSpace(raw.Sort)
	validSorts := map[string]bool{"": true, "price_asc": true, "price_desc": true, "stock_asc": true}
	if !validSorts[sort] {
		return SellerOfferListResult{}, models.NewValidationError("INVALID_SORT", "sort must be one of: price_asc, price_desc, stock_asc")
	}

	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return SellerOfferListResult{}, err
	}

	query := models.SellerOfferQuery{
		Search:   strings.TrimSpace(raw.Search),
		Status:   status,
		LowStock: raw.LowStock == "true" || raw.LowStock == "1",
		Sort:     sort,
		Limit:    limit,
		Offset:   offset,
	}

	items, total, err := s.offerRepo.List(ctx, sellerID, query)
	if err != nil {
		return SellerOfferListResult{}, err
	}
	return SellerOfferListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

// validateOfferFields is shared by Create and Update (Stage 7 §7/§8):
// price/old_price must be valid non-negative decimals, delivery_days >= 0.
// SKU uniqueness-per-seller is enforced by the DB's own UNIQUE constraint,
// not duplicated here — the repository maps the resulting unique_violation
// to a clean error instead.
func validateOfferFields(sku, price, oldPrice string, deliveryDays int) error {
	if strings.TrimSpace(sku) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "sku is required")
	}
	if !decimalPattern.MatchString(price) {
		return models.NewValidationError("INVALID_PRICE", "price must be a non-negative decimal amount, e.g. \"250000.00\"")
	}
	if oldPrice != "" && !decimalPattern.MatchString(oldPrice) {
		return models.NewValidationError("INVALID_OLD_PRICE", "old_price must be a non-negative decimal amount, e.g. \"270000.00\"")
	}
	if deliveryDays < 0 {
		return models.NewValidationError("INVALID_DELIVERY_DAYS", "delivery_days must be zero or a positive integer")
	}
	return nil
}

// Create adds an offer against an existing, active catalog product (Stage
// 7 §7/§35) — never a new product record.
func (s *SellerOfferService) Create(ctx context.Context, sellerID int64, in models.CreateOfferInput) (int64, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return 0, err
	}
	if in.ProductID <= 0 {
		return 0, models.NewValidationError("VALIDATION_ERROR", "product_id is required")
	}
	if err := validateOfferFields(in.SKU, in.Price, in.OldPrice, in.DeliveryDays); err != nil {
		return 0, err
	}
	if in.Stock < 0 {
		return 0, models.NewValidationError("INVALID_STOCK", "stock must be zero or a positive integer")
	}

	exists, err := s.productRepo.Exists(ctx, in.ProductID)
	if err != nil {
		return 0, err
	}
	if !exists {
		return 0, models.NewNotFoundError("PRODUCT_NOT_FOUND", "Product not found")
	}

	id, err := s.offerRepo.Create(ctx, sellerID, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return 0, models.NewConflictError("SKU_ALREADY_EXISTS", "You already have an offer with this SKU")
		}
		return 0, err
	}
	return id, nil
}

func (s *SellerOfferService) Update(ctx context.Context, sellerID, offerID int64, in models.UpdateOfferInput) error {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return err
	}
	if err := validateOfferFields(in.SKU, in.Price, in.OldPrice, in.DeliveryDays); err != nil {
		return err
	}

	err := s.offerRepo.Update(ctx, sellerID, offerID, in)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			return models.NewConflictError("SKU_ALREADY_EXISTS", "You already have an offer with this SKU")
		}
		return err
	}
	return nil
}

func (s *SellerOfferService) UpdateStatus(ctx context.Context, sellerID, offerID int64, isActive bool) error {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return err
	}
	return s.offerRepo.UpdateStatus(ctx, sellerID, offerID, isActive)
}

func (s *SellerOfferService) ListInventory(ctx context.Context, sellerID int64) ([]models.SellerInventoryItem, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	return s.offerRepo.ListInventory(ctx, sellerID)
}

func (s *SellerOfferService) UpdateInventory(ctx context.Context, sellerID, offerID int64, availableQuantity int) error {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return err
	}
	if availableQuantity < 0 {
		return models.NewValidationError("INVALID_STOCK", "available_quantity must be zero or a positive integer")
	}
	return s.offerRepo.UpdateInventory(ctx, sellerID, offerID, availableQuantity)
}
