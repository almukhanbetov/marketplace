package services

import (
	"context"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminSellerService struct {
	repo *repositories.AdminSellerRepository
}

func NewAdminSellerService(repo *repositories.AdminSellerRepository) *AdminSellerService {
	return &AdminSellerService{repo: repo}
}

type AdminSellerListResult struct {
	Items  []models.AdminSellerListItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminSellerQuery struct {
	Search   string
	Verified string
	Status   string
	Sort     string
	Limit    string
	Offset   string
}

var validAdminSellerSorts = map[string]bool{"": true, "created_at_asc": true, "created_at_desc": true, "rating_desc": true, "name_asc": true}

func (s *AdminSellerService) List(ctx context.Context, raw RawAdminSellerQuery) (AdminSellerListResult, error) {
	status := strings.TrimSpace(raw.Status)
	if !validStatusFilters[status] {
		return AdminSellerListResult{}, models.NewValidationError("INVALID_STATUS", "status must be one of: active, inactive")
	}
	sort := strings.TrimSpace(raw.Sort)
	if !validAdminSellerSorts[sort] {
		return AdminSellerListResult{}, models.NewValidationError("INVALID_SORT", "sort must be one of: created_at_asc, created_at_desc, rating_desc, name_asc")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminSellerListResult{}, err
	}

	var verified *bool
	if v := strings.TrimSpace(raw.Verified); v != "" {
		b, err := strconv.ParseBool(v)
		if err != nil {
			return AdminSellerListResult{}, models.NewValidationError("INVALID_VERIFIED", "verified must be true or false")
		}
		verified = &b
	}

	items, total, err := s.repo.List(ctx, models.AdminSellerQuery{
		Search: strings.TrimSpace(raw.Search), Verified: verified, Status: status, Sort: sort, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminSellerListResult{}, err
	}
	return AdminSellerListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *AdminSellerService) GetDetail(ctx context.Context, id int64) (*models.AdminSellerDetail, error) {
	return s.repo.GetDetail(ctx, id)
}

// UpdateStatus deactivates/reactivates a seller. Deactivating automatically
// hides their offers from the public catalog via the existing Stage 3
// valid_offers rule (sellers.is_active = TRUE) — no separate action needed
// here, and offers are never deleted (Stage 8 §11).
func (s *AdminSellerService) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	return s.repo.UpdateStatus(ctx, id, isActive)
}

func (s *AdminSellerService) UpdateVerification(ctx context.Context, id int64, isVerified bool) error {
	return s.repo.UpdateVerification(ctx, id, isVerified)
}
