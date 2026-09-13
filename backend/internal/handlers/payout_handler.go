package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type PayoutHandler struct {
	service *services.PayoutService
	logger  *slog.Logger
}

func NewPayoutHandler(service *services.PayoutService, logger *slog.Logger) *PayoutHandler {
	return &PayoutHandler{service: service, logger: logger}
}

// List handles GET /api/v1/seller/payouts.
func (h *PayoutHandler) List(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	payouts, err := h.service.List(c.Request.Context(), sellerID)
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, payouts)
}

// createPayoutRequest is the POST /payouts body (Stage 7 §21) — draws only
// from available_amount, never pending_amount. The idempotency key may
// arrive as a header (preferred) or this field, matching Stage 6 orders.
type createPayoutRequest struct {
	Amount         string `json:"amount"`
	IdempotencyKey string `json:"idempotency_key"`
}

// Create handles POST /api/v1/seller/payouts.
func (h *PayoutHandler) Create(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	var req createPayoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include amount")
		return
	}

	idempotencyKey := c.GetHeader("Idempotency-Key")
	if idempotencyKey == "" {
		idempotencyKey = req.IdempotencyKey
	}

	payout, err := h.service.Create(c.Request.Context(), sellerID, models.CreatePayoutInput{
		Amount:         req.Amount,
		IdempotencyKey: idempotencyKey,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusCreated, payout)
}
