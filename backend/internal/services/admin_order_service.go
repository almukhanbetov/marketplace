package services

import (
	"context"
	"regexp"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// datePattern accepts a plain YYYY-MM-DD date (Stage 8 order/payment date
// filters) — validated by shape only; Postgres rejects an impossible
// calendar date (e.g. 2026-02-30) itself when cast to ::date.
var datePattern = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)

type AdminOrderService struct {
	repo *repositories.AdminOrderRepository
}

func NewAdminOrderService(repo *repositories.AdminOrderRepository) *AdminOrderService {
	return &AdminOrderService{repo: repo}
}

type AdminOrderListResult struct {
	Items  []models.AdminOrderListItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminOrderQuery struct {
	Status   string
	UserID   string
	DateFrom string
	DateTo   string
	MinTotal string
	MaxTotal string
	Sort     string
	Limit    string
	Offset   string
}

var validAdminOrderStatuses = map[string]bool{
	"": true, "new": true, "confirmed": true, "paid": true, "processing": true,
	"shipped": true, "delivered": true, "cancelled": true, "returned": true,
}
var validAdminOrderSorts = map[string]bool{"": true, "created_at_asc": true, "created_at_desc": true, "total_asc": true, "total_desc": true}

func (s *AdminOrderService) List(ctx context.Context, raw RawAdminOrderQuery) (AdminOrderListResult, error) {
	status := strings.TrimSpace(raw.Status)
	if !validAdminOrderStatuses[status] {
		return AdminOrderListResult{}, models.NewValidationError("INVALID_STATUS", "status must be a valid order status")
	}
	sort := strings.TrimSpace(raw.Sort)
	if !validAdminOrderSorts[sort] {
		return AdminOrderListResult{}, models.NewValidationError("INVALID_SORT", "sort must be one of: created_at_asc, created_at_desc, total_asc, total_desc")
	}
	if raw.DateFrom != "" && !datePattern.MatchString(raw.DateFrom) {
		return AdminOrderListResult{}, models.NewValidationError("INVALID_DATE_FROM", "date_from must be YYYY-MM-DD")
	}
	if raw.DateTo != "" && !datePattern.MatchString(raw.DateTo) {
		return AdminOrderListResult{}, models.NewValidationError("INVALID_DATE_TO", "date_to must be YYYY-MM-DD")
	}
	minTotal, err := parseDecimalParam(raw.MinTotal, "min_total")
	if err != nil {
		return AdminOrderListResult{}, err
	}
	maxTotal, err := parseDecimalParam(raw.MaxTotal, "max_total")
	if err != nil {
		return AdminOrderListResult{}, err
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminOrderListResult{}, err
	}

	var userID *int64
	if raw.UserID != "" {
		id, parseErr := strconv.ParseInt(raw.UserID, 10, 64)
		if parseErr != nil || id <= 0 {
			return AdminOrderListResult{}, models.NewValidationError("INVALID_USER_ID", "user must be a positive integer")
		}
		userID = &id
	}

	items, total, err := s.repo.List(ctx, models.AdminOrderQuery{
		Status: status, UserID: userID, DateFrom: raw.DateFrom, DateTo: raw.DateTo,
		MinTotal: minTotal, MaxTotal: maxTotal, Sort: sort, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminOrderListResult{}, err
	}
	return AdminOrderListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *AdminOrderService) GetDetail(ctx context.Context, id int64) (*models.AdminOrderDetail, error) {
	return s.repo.GetDetail(ctx, id)
}
