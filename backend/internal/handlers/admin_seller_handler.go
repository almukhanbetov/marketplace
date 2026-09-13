package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AdminSellerHandler struct {
	service *services.AdminSellerService
	logger  *slog.Logger
}

func NewAdminSellerHandler(service *services.AdminSellerService, logger *slog.Logger) *AdminSellerHandler {
	return &AdminSellerHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/sellers.
func (h *AdminSellerHandler) List(c *gin.Context) {
	raw := services.RawAdminSellerQuery{
		Search: c.Query("search"), Verified: c.Query("verified"), Status: c.Query("status"),
		Sort: c.Query("sort"), Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.List(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// Get handles GET /api/v1/admin/sellers/:id.
func (h *AdminSellerHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	detail, err := h.service.GetDetail(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, detail)
}

type updateSellerStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// UpdateStatus handles PATCH /api/v1/admin/sellers/:id/status.
func (h *AdminSellerHandler) UpdateStatus(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateSellerStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_active")
		return
	}
	if err := h.service.UpdateStatus(c.Request.Context(), id, req.IsActive); err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}

type updateSellerVerificationRequest struct {
	IsVerified bool `json:"is_verified"`
}

// UpdateVerification handles PATCH /api/v1/admin/sellers/:id/verification.
func (h *AdminSellerHandler) UpdateVerification(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateSellerVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_verified")
		return
	}
	if err := h.service.UpdateVerification(c.Request.Context(), id, req.IsVerified); err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
