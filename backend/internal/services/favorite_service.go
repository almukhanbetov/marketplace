package services

import (
	"context"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type FavoriteService struct {
	favoriteRepo *repositories.FavoriteRepository
	userRepo     *repositories.UserRepository
	productRepo  *repositories.ProductRepository
}

func NewFavoriteService(favoriteRepo *repositories.FavoriteRepository, userRepo *repositories.UserRepository, productRepo *repositories.ProductRepository) *FavoriteService {
	return &FavoriteService{favoriteRepo: favoriteRepo, userRepo: userRepo, productRepo: productRepo}
}

// List returns the user's favorited products as full product cards.
func (s *FavoriteService) List(ctx context.Context, userID int64) ([]models.ProductCard, error) {
	exists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	return s.favoriteRepo.List(ctx, userID)
}

// Add validates both the user and product exist, then adds the favorite
// (idempotent — adding twice never duplicates a row, Stage 5 §5).
func (s *FavoriteService) Add(ctx context.Context, userID, productID int64) error {
	userExists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return err
	}
	if !userExists {
		return models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}

	productExists, err := s.productRepo.Exists(ctx, productID)
	if err != nil {
		return err
	}
	if !productExists {
		return models.NewNotFoundError("PRODUCT_NOT_FOUND", "Product not found")
	}

	return s.favoriteRepo.Add(ctx, userID, productID)
}

// Remove validates the user exists, then removes the favorite if present
// (idempotent — no error if it was already absent, Stage 5 §6).
func (s *FavoriteService) Remove(ctx context.Context, userID, productID int64) error {
	exists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return err
	}
	if !exists {
		return models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	return s.favoriteRepo.Remove(ctx, userID, productID)
}
