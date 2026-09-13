package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminPayoutService struct {
	repo *repositories.AdminPayoutRepository
}

func NewAdminPayoutService(repo *repositories.AdminPayoutRepository) *AdminPayoutService {
	return &AdminPayoutService{repo: repo}
}

type AdminPayoutListResult struct {
	Items  []models.AdminPayoutItem
	Total  int
	Limit  int
	Offset int
}

var validAdminPayoutStatuses = map[string]bool{"": true, "pending": true, "processing": true, "paid": true, "rejected": true}

func (s *AdminPayoutService) List(ctx context.Context, rawStatus, rawLimit, rawOffset string) (AdminPayoutListResult, error) {
	status := strings.TrimSpace(rawStatus)
	if !validAdminPayoutStatuses[status] {
		return AdminPayoutListResult{}, models.NewValidationError("INVALID_STATUS", "status must be one of: pending, processing, paid, rejected")
	}
	limit, offset, err := parsePagination(rawLimit, rawOffset)
	if err != nil {
		return AdminPayoutListResult{}, err
	}
	items, total, err := s.repo.List(ctx, models.AdminPayoutQuery{Status: status, Limit: limit, Offset: offset})
	if err != nil {
		return AdminPayoutListResult{}, err
	}
	return AdminPayoutListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *AdminPayoutService) GetByID(ctx context.Context, id int64) (*models.AdminPayoutItem, error) {
	return s.repo.GetByID(ctx, id)
}

// UpdateStatus performs one payout state transition (Stage 8 §25-§30).
// The entire read-validate-write sequence happens inside a single
// transaction with the payout row locked FOR UPDATE, so this is safe
// against duplicate/concurrent requests by construction: a second request
// racing the first either blocks until the first commits (then sees the
// already-changed status and gets INVALID_PAYOUT_STATUS_TRANSITION, since
// paid/rejected are terminal and pending->processing->X only ever accepts
// each transition once) or the two serialize and the second cleanly fails
// validation — never a double balance mutation (Stage 8 §30).
//
//   - pending/processing -> rejected: refunds the payout amount back to
//     the seller's available_amount (Stage 8 §27/§28) — exactly once,
//     because a payout can only ever leave "pending"/"processing" through
//     this locked transaction one time.
//   - processing -> paid: status/processed_at only, no balance change —
//     Stage 7's payout request already decremented available_amount at
//     creation time (Stage 8 §29).
func (s *AdminPayoutService) UpdateStatus(ctx context.Context, payoutID int64, newStatus models.PayoutStatus) (*models.AdminPayoutItem, error) {
	tx, err := s.repo.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin payout transition transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	current, err := s.repo.LockPayoutForUpdate(ctx, tx, payoutID)
	if err != nil {
		return nil, err
	}

	if !models.IsValidPayoutTransition(current.Status, newStatus) {
		return nil, models.NewConflictError(
			"INVALID_PAYOUT_STATUS_TRANSITION",
			fmt.Sprintf("Cannot transition a payout from %s to %s", current.Status, newStatus),
		)
	}

	switch newStatus {
	case models.PayoutStatusRejected:
		if err := s.repo.RefundSellerBalance(ctx, tx, current.SellerID, current.Amount); err != nil {
			return nil, err
		}
		if err := s.repo.SetStatus(ctx, tx, payoutID, models.PayoutStatusRejected, true); err != nil {
			return nil, err
		}
	case models.PayoutStatusPaid:
		if err := s.repo.SetStatus(ctx, tx, payoutID, models.PayoutStatusPaid, true); err != nil {
			return nil, err
		}
	case models.PayoutStatusProcessing:
		if err := s.repo.SetStatus(ctx, tx, payoutID, models.PayoutStatusProcessing, false); err != nil {
			return nil, err
		}
	default:
		return nil, models.NewValidationError("VALIDATION_ERROR", "status must be one of: processing, paid, rejected")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit payout transition transaction: %w", err)
	}
	return s.repo.GetByID(ctx, payoutID)
}
