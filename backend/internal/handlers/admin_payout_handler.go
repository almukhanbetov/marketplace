package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AdminPayoutHandler struct {
	service *services.AdminPayoutService
	logger  *slog.Logger
}

func NewAdminPayoutHandler(service *services.AdminPayoutService, logger *slog.Logger) *AdminPayoutHandler {
	return &AdminPayoutHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/payouts.
func (h *AdminPayoutHandler) List(c *gin.Context) {
	result, err := h.service.List(c.Request.Context(), c.Query("status"), c.Query("limit"), c.Query("offset"))
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// Get handles GET /api/v1/admin/payouts/:id.
func (h *AdminPayoutHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	payout, err := h.service.GetByID(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "PAYOUT_NOT_FOUND", "Payout not found")
		return
	}
	response.Success(c, http.StatusOK, payout)
}

type updatePayoutStatusRequest struct {
	Status string `json:"status"`
}

// UpdateStatus handles PATCH /api/v1/admin/payouts/:id/status. Allowed
// target statuses are processing/paid/rejected (Stage 8 §26) — the
// service validates the actual from->to transition against
// models.PayoutTransitions.
func (h *AdminPayoutHandler) UpdateStatus(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updatePayoutStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include status")
		return
	}
	payout, err := h.service.UpdateStatus(c.Request.Context(), id, models.PayoutStatus(req.Status))
	if err != nil {
		writeServiceError(c, h.logger, err, "PAYOUT_NOT_FOUND", "Payout not found")
		return
	}
	response.Success(c, http.StatusOK, payout)
}
