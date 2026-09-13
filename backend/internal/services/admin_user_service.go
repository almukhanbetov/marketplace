package services

import (
	"context"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

type AdminUserService struct {
	repo *repositories.AdminUserRepository
}

func NewAdminUserService(repo *repositories.AdminUserRepository) *AdminUserService {
	return &AdminUserService{repo: repo}
}

// AdminUserListResult bundles a page of users with the total count.
type AdminUserListResult struct {
	Items  []models.User
	Total  int
	Limit  int
	Offset int
}

// RawAdminUserQuery is what the handler extracts from gin.Context — raw
// strings, validated here (Stage 8 §41).
type RawAdminUserQuery struct {
	Search string
	Role   string
	Status string
	Sort   string
	Limit  string
	Offset string
}

var validUserRoles = map[string]bool{"": true, "customer": true, "seller": true, "admin": true}
var validStatusFilters = map[string]bool{"": true, "active": true, "inactive": true}
var validUserSorts = map[string]bool{"": true, "created_at_asc": true, "created_at_desc": true, "name_asc": true}

func (s *AdminUserService) List(ctx context.Context, raw RawAdminUserQuery) (AdminUserListResult, error) {
	role := strings.TrimSpace(raw.Role)
	if !validUserRoles[role] {
		return AdminUserListResult{}, models.NewValidationError("INVALID_ROLE", "role must be one of: customer, seller, admin")
	}
	status := strings.TrimSpace(raw.Status)
	if !validStatusFilters[status] {
		return AdminUserListResult{}, models.NewValidationError("INVALID_STATUS", "status must be one of: active, inactive")
	}
	sort := strings.TrimSpace(raw.Sort)
	if !validUserSorts[sort] {
		return AdminUserListResult{}, models.NewValidationError("INVALID_SORT", "sort must be one of: created_at_asc, created_at_desc, name_asc")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminUserListResult{}, err
	}

	items, total, err := s.repo.List(ctx, models.UserQuery{
		Search: strings.TrimSpace(raw.Search), Role: role, Status: status, Sort: sort, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminUserListResult{}, err
	}
	return AdminUserListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *AdminUserService) GetDetail(ctx context.Context, id int64) (*models.UserDetail, error) {
	return s.repo.GetDetail(ctx, id)
}

// UpdateStatus deactivates/reactivates a user account. This is admin
// STATE only in Stage 8 — with no authentication yet, it cannot enforce
// login blocking; that enforcement arrives with Stage 9 auth (Stage 8 §65).
func (s *AdminUserService) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	return s.repo.UpdateStatus(ctx, id, isActive)
}
