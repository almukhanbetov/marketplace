package services

import (
	"context"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// AdminFinanceService covers payments + commissions — consolidated the
// same way AdminFinanceRepository is (Stage 8 §38/§39).
type AdminFinanceService struct {
	repo *repositories.AdminFinanceRepository
}

func NewAdminFinanceService(repo *repositories.AdminFinanceRepository) *AdminFinanceService {
	return &AdminFinanceService{repo: repo}
}

type AdminPaymentListResult struct {
	Items  []models.AdminPaymentItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminPaymentQuery struct {
	Status   string
	Provider string
	DateFrom string
	DateTo   string
	Limit    string
	Offset   string
}

var validPaymentStatuses = map[string]bool{"": true, "pending": true, "paid": true, "failed": true, "cancelled": true, "refunded": true}
var validPaymentProviders = map[string]bool{"": true, "card": true, "kaspi_mock": true, "apple_pay_mock": true, "google_pay_mock": true}

func (s *AdminFinanceService) ListPayments(ctx context.Context, raw RawAdminPaymentQuery) (AdminPaymentListResult, error) {
	status := strings.TrimSpace(raw.Status)
	if !validPaymentStatuses[status] {
		return AdminPaymentListResult{}, models.NewValidationError("INVALID_STATUS", "status must be a valid payment status")
	}
	provider := strings.TrimSpace(raw.Provider)
	if !validPaymentProviders[provider] {
		return AdminPaymentListResult{}, models.NewValidationError("INVALID_PROVIDER", "provider must be a valid payment provider")
	}
	if raw.DateFrom != "" && !datePattern.MatchString(raw.DateFrom) {
		return AdminPaymentListResult{}, models.NewValidationError("INVALID_DATE_FROM", "date_from must be YYYY-MM-DD")
	}
	if raw.DateTo != "" && !datePattern.MatchString(raw.DateTo) {
		return AdminPaymentListResult{}, models.NewValidationError("INVALID_DATE_TO", "date_to must be YYYY-MM-DD")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminPaymentListResult{}, err
	}

	items, total, err := s.repo.ListPayments(ctx, models.AdminPaymentQuery{
		Status: status, Provider: provider, DateFrom: raw.DateFrom, DateTo: raw.DateTo, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminPaymentListResult{}, err
	}
	return AdminPaymentListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

type AdminCommissionListResult struct {
	Items  []models.AdminCommissionItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminCommissionQuery struct {
	SellerID string
	DateFrom string
	DateTo   string
	Limit    string
	Offset   string
}

func (s *AdminFinanceService) ListCommissions(ctx context.Context, raw RawAdminCommissionQuery) (AdminCommissionListResult, error) {
	if raw.DateFrom != "" && !datePattern.MatchString(raw.DateFrom) {
		return AdminCommissionListResult{}, models.NewValidationError("INVALID_DATE_FROM", "date_from must be YYYY-MM-DD")
	}
	if raw.DateTo != "" && !datePattern.MatchString(raw.DateTo) {
		return AdminCommissionListResult{}, models.NewValidationError("INVALID_DATE_TO", "date_to must be YYYY-MM-DD")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminCommissionListResult{}, err
	}

	var sellerID *int64
	if raw.SellerID != "" {
		id, parseErr := strconv.ParseInt(raw.SellerID, 10, 64)
		if parseErr != nil || id <= 0 {
			return AdminCommissionListResult{}, models.NewValidationError("INVALID_SELLER_ID", "seller must be a positive integer")
		}
		sellerID = &id
	}

	items, total, err := s.repo.ListCommissions(ctx, models.AdminCommissionQuery{
		SellerID: sellerID, DateFrom: raw.DateFrom, DateTo: raw.DateTo, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminCommissionListResult{}, err
	}
	return AdminCommissionListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}
