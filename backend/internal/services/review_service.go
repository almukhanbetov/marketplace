package services

import (
	"context"
	"strconv"
	"strings"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/repositories"
)

// ReviewService covers both the public reviews endpoint and admin
// moderation — consolidated the same way ReviewRepository is (Stage 8
// §31-§37).
type ReviewService struct {
	repo        *repositories.ReviewRepository
	productRepo *repositories.ProductRepository
}

func NewReviewService(repo *repositories.ReviewRepository, productRepo *repositories.ProductRepository) *ReviewService {
	return &ReviewService{repo: repo, productRepo: productRepo}
}

type PublicReviewListResult struct {
	Items  []models.PublicReview
	Total  int
	Limit  int
	Offset int
}

// ListPublic returns only visible reviews for a product. Deliberately
// does not require the product itself to be "active" — a deactivated
// product's existing reviews are still a real historical record, just no
// longer purchasable (Stage 8 §16 applies to purchasability, not review
// history).
func (s *ReviewService) ListPublic(ctx context.Context, productID int64, rawLimit, rawOffset string) (PublicReviewListResult, error) {
	exists, err := s.productRepo.Exists(ctx, productID)
	if err != nil {
		return PublicReviewListResult{}, err
	}
	if !exists {
		return PublicReviewListResult{}, models.NewNotFoundError("PRODUCT_NOT_FOUND", "Product not found")
	}

	limit, offset, err := parsePagination(rawLimit, rawOffset)
	if err != nil {
		return PublicReviewListResult{}, err
	}
	items, total, err := s.repo.ListPublic(ctx, productID, limit, offset)
	if err != nil {
		return PublicReviewListResult{}, err
	}
	return PublicReviewListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

type AdminReviewListResult struct {
	Items  []models.AdminReviewItem
	Total  int
	Limit  int
	Offset int
}

type RawAdminReviewQuery struct {
	ProductID string
	Rating    string
	Visible   string
	UserID    string
	Sort      string
	Limit     string
	Offset    string
}

var validVisibleFilters = map[string]bool{"": true, "true": true, "false": true}

func (s *ReviewService) ListAdmin(ctx context.Context, raw RawAdminReviewQuery) (AdminReviewListResult, error) {
	visible := strings.TrimSpace(raw.Visible)
	if !validVisibleFilters[visible] {
		return AdminReviewListResult{}, models.NewValidationError("INVALID_VISIBLE", "visible must be true or false")
	}
	limit, offset, err := parsePagination(raw.Limit, raw.Offset)
	if err != nil {
		return AdminReviewListResult{}, err
	}

	var productID *int64
	if raw.ProductID != "" {
		id, parseErr := strconv.ParseInt(raw.ProductID, 10, 64)
		if parseErr != nil || id <= 0 {
			return AdminReviewListResult{}, models.NewValidationError("INVALID_PRODUCT_ID", "product must be a positive integer")
		}
		productID = &id
	}
	var userID *int64
	if raw.UserID != "" {
		id, parseErr := strconv.ParseInt(raw.UserID, 10, 64)
		if parseErr != nil || id <= 0 {
			return AdminReviewListResult{}, models.NewValidationError("INVALID_USER_ID", "user must be a positive integer")
		}
		userID = &id
	}
	var rating *int
	if raw.Rating != "" {
		r, parseErr := strconv.Atoi(raw.Rating)
		if parseErr != nil || r < 1 || r > 5 {
			return AdminReviewListResult{}, models.NewValidationError("INVALID_RATING", "rating must be between 1 and 5")
		}
		rating = &r
	}

	items, total, err := s.repo.ListAdmin(ctx, models.AdminReviewQuery{
		ProductID: productID, Rating: rating, Visible: visible, UserID: userID, Sort: raw.Sort, Limit: limit, Offset: offset,
	})
	if err != nil {
		return AdminReviewListResult{}, err
	}
	return AdminReviewListResult{Items: items, Total: total, Limit: limit, Offset: offset}, nil
}

func (s *ReviewService) GetByID(ctx context.Context, id int64) (*models.AdminReviewItem, error) {
	return s.repo.GetByID(ctx, id)
}

// UpdateVisibility hides/shows a review and recalculates the product's
// rating/review_count from its remaining visible reviews, transactionally
// (Stage 8 §34/§35/§36). Never physically deletes the review.
func (s *ReviewService) UpdateVisibility(ctx context.Context, id int64, isVisible bool) error {
	return s.repo.UpdateVisibility(ctx, id, isVisible)
}
