package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type SellerFinanceHandler struct {
	service *services.SellerFinanceService
	logger  *slog.Logger
}

func NewSellerFinanceHandler(service *services.SellerFinanceService, logger *slog.Logger) *SellerFinanceHandler {
	return &SellerFinanceHandler{service: service, logger: logger}
}

// GetSummary handles GET /api/v1/seller/finance.
func (h *SellerFinanceHandler) GetSummary(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	summary, err := h.service.GetSummary(c.Request.Context(), sellerID)
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, summary)
}
