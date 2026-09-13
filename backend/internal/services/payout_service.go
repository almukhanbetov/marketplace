package services

import (
	"context"
	"errors"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/money"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type PayoutService struct {
	payoutRepo *repositories.PayoutRepository
	sellerRepo *repositories.SellerRepository
}

func NewPayoutService(payoutRepo *repositories.PayoutRepository, sellerRepo *repositories.SellerRepository) *PayoutService {
	return &PayoutService{payoutRepo: payoutRepo, sellerRepo: sellerRepo}
}

func (s *PayoutService) List(ctx context.Context, sellerID int64) ([]models.Payout, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	return s.payoutRepo.List(ctx, sellerID)
}

// errPayoutIdempotentRace mirrors Stage 6 order creation's
// errIdempotentRace — signals Create to re-resolve the idempotency key
// after losing a concurrent-insert race.
var errPayoutIdempotentRace = errors.New("idempotent race: payout already created by a concurrent request")

// Create requests a payout from available_amount only (Stage 7 §21) —
// idempotent on (seller_id, idempotency_key) exactly like Stage 6 orders
// (§24/§65).
func (s *PayoutService) Create(ctx context.Context, sellerID int64, in models.CreatePayoutInput) (*models.Payout, error) {
	if err := requireSeller(ctx, s.sellerRepo, sellerID); err != nil {
		return nil, err
	}
	if err := parsePositiveMoney(in.Amount); err != nil {
		return nil, models.NewValidationError("VALIDATION_ERROR", "amount must be a positive decimal amount, e.g. \"50000.00\"")
	}
	if money.ToCents(in.Amount) <= 0 {
		return nil, models.NewValidationError("VALIDATION_ERROR", "amount must be greater than zero")
	}

	if in.IdempotencyKey != "" {
		existingID, err := s.payoutRepo.FindIDByIdempotencyKey(ctx, sellerID, in.IdempotencyKey)
		if err != nil {
			return nil, err
		}
		if existingID != nil {
			return s.payoutRepo.GetByID(ctx, sellerID, *existingID)
		}
	}

	payoutID, err := s.payoutRepo.Create(ctx, sellerID, in.Amount, in.IdempotencyKey)
	if err != nil {
		if repositories.IsUniqueViolation(err) {
			existingID, lookupErr := s.payoutRepo.FindIDByIdempotencyKey(ctx, sellerID, in.IdempotencyKey)
			if lookupErr != nil {
				return nil, lookupErr
			}
			if existingID != nil {
				return s.payoutRepo.GetByID(ctx, sellerID, *existingID)
			}
			return nil, errPayoutIdempotentRace
		}
		return nil, err
	}

	return s.payoutRepo.GetByID(ctx, sellerID, payoutID)
}
