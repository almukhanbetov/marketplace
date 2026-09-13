package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type SellerDashboardHandler struct {
	service *services.SellerDashboardService
	logger  *slog.Logger
}

func NewSellerDashboardHandler(service *services.SellerDashboardService, logger *slog.Logger) *SellerDashboardHandler {
	return &SellerDashboardHandler{service: service, logger: logger}
}

// GetSummary handles GET /api/v1/seller/dashboard. The seller id comes
// exclusively from the authenticated caller's linked active seller
// account (Stage 9 §23/§52) — there is no seller id in this URL at all.
func (h *SellerDashboardHandler) GetSummary(c *gin.Context) {
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
