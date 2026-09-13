package services

import (
	"context"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AddressService struct {
	addressRepo *repositories.AddressRepository
	userRepo    *repositories.UserRepository
}

func NewAddressService(addressRepo *repositories.AddressRepository, userRepo *repositories.UserRepository) *AddressService {
	return &AddressService{addressRepo: addressRepo, userRepo: userRepo}
}

func (s *AddressService) requireUser(ctx context.Context, userID int64) error {
	exists, err := s.userRepo.Exists(ctx, userID)
	if err != nil {
		return err
	}
	if !exists {
		return models.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	return nil
}

// validateInput enforces Stage 5 §18: city/street/house required,
// title/postal_code/apartment optional.
func validateAddressInput(in models.AddressInput) error {
	if strings.TrimSpace(in.City) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "city is required")
	}
	if strings.TrimSpace(in.Street) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "street is required")
	}
	if strings.TrimSpace(in.House) == "" {
		return models.NewValidationError("VALIDATION_ERROR", "house is required")
	}
	return nil
}

func (s *AddressService) List(ctx context.Context, userID int64) ([]models.Address, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.addressRepo.List(ctx, userID)
}

func (s *AddressService) Create(ctx context.Context, userID int64, in models.AddressInput) (*models.Address, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	if err := validateAddressInput(in); err != nil {
		return nil, err
	}
	return s.addressRepo.Create(ctx, userID, in)
}

func (s *AddressService) Update(ctx context.Context, userID, addressID int64, in models.AddressInput) (*models.Address, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	if err := validateAddressInput(in); err != nil {
		return nil, err
	}
	return s.addressRepo.Update(ctx, userID, addressID, in)
}

func (s *AddressService) SetDefault(ctx context.Context, userID, addressID int64) (*models.Address, error) {
	if err := s.requireUser(ctx, userID); err != nil {
		return nil, err
	}
	return s.addressRepo.SetDefault(ctx, userID, addressID)
}

func (s *AddressService) Delete(ctx context.Context, userID, addressID int64) error {
	if err := s.requireUser(ctx, userID); err != nil {
		return err
	}
	return s.addressRepo.Delete(ctx, userID, addressID)
}
