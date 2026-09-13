package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// ReviewHandler covers both the public reviews endpoint and admin
// moderation — consolidated the same way the repository/service layers
// are (Stage 8 §31-§37).
type ReviewHandler struct {
	service *services.ReviewService
	logger  *slog.Logger
}

func NewReviewHandler(service *services.ReviewService, logger *slog.Logger) *ReviewHandler {
	return &ReviewHandler{service: service, logger: logger}
}

// ListPublic handles GET /api/v1/products/:id/reviews.
func (h *ReviewHandler) ListPublic(c *gin.Context) {
	productID, ok := parsePathID(c)
	if !ok {
		return
	}
	result, err := h.service.ListPublic(c.Request.Context(), productID, c.Query("limit"), c.Query("offset"))
	if err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// ListAdmin handles GET /api/v1/admin/reviews.
func (h *ReviewHandler) ListAdmin(c *gin.Context) {
	raw := services.RawAdminReviewQuery{
		ProductID: c.Query("product"), Rating: c.Query("rating"), Visible: c.Query("visible"), UserID: c.Query("user"),
		Sort: c.Query("sort"), Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.ListAdmin(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// GetAdmin handles GET /api/v1/admin/reviews/:id.
func (h *ReviewHandler) GetAdmin(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	review, err := h.service.GetByID(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "REVIEW_NOT_FOUND", "Review not found")
		return
	}
	response.Success(c, http.StatusOK, review)
}

type updateReviewVisibilityRequest struct {
	IsVisible bool `json:"is_visible"`
}

// UpdateVisibility handles PATCH /api/v1/admin/reviews/:id/visibility.
func (h *ReviewHandler) UpdateVisibility(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateReviewVisibilityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_visible")
		return
	}
	if err := h.service.UpdateVisibility(c.Request.Context(), id, req.IsVisible); err != nil {
		writeServiceError(c, h.logger, err, "REVIEW_NOT_FOUND", "Review not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
