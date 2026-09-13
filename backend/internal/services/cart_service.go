package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type CartService struct {
	cartRepo *repositories.CartRepository
	userRepo *repositories.UserRepository
}

func NewCartService(cartRepo *repositories.CartRepository, userRepo *repositories.UserRepository) *CartService {
	return &CartService{cartRepo: cartRepo, userRepo: userRepo}
}

func (s *CartService) requireUser(ctx context.Context, userID int64) error {
	exists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return err
	}
	if !exists {
		return models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	return nil
}

// Get returns the user's cart (empty if they've never added anything).
func (s *CartService) Get(ctx context.Context, userID int64) (*models.Cart, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.cartRepo.Get(ctx, userID)
}

// AddItem validates quantity > 0 then delegates to the repository, which
// validates the offer/seller/product are active and there's enough stock
// (Stage 5 §9) inside a transaction (§10/§21/§22).
func (s *CartService) AddItem(ctx context.Context, userID, sellerOfferID int64, quantity int) (*models.Cart, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	if sellerOfferID <= 0 {
		return nil, models.NewValidationError("VALIDATION_ERROR", "seller_offer_id must be a positive integer")
	}
	if quantity <= 0 {
		return nil, models.NewValidationError("VALIDATION_ERROR", "quantity must be greater than zero")
	}
	return s.cartRepo.AddItem(ctx, userID, sellerOfferID, quantity)
}

// UpdateItemQuantity validates quantity > 0 (Stage 5 §14 — a request to set
// quantity to 0 is rejected; use RemoveItem instead) then delegates.
func (s *CartService) UpdateItemQuantity(ctx context.Context, userID, itemID int64, quantity int) (*models.Cart, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	if quantity <= 0 {
		return nil, models.NewValidationError("VALIDATION_ERROR", "quantity must be greater than zero; use DELETE to remove an item")
	}
	return s.cartRepo.UpdateItemQuantity(ctx, userID, itemID, quantity)
}

func (s *CartService) RemoveItem(ctx context.Context, userID, itemID int64) (*models.Cart, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.cartRepo.RemoveItem(ctx, userID, itemID)
}

func (s *CartService) Clear(ctx context.Context, userID int64) (*models.Cart, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.cartRepo.Clear(ctx, userID)
}
