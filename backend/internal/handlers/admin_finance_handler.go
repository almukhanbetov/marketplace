package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// AdminFinanceHandler covers payments + commissions — consolidated the
// same way the repository/service layers are (Stage 8 §38/§39).
type AdminFinanceHandler struct {
	service *services.AdminFinanceService
	logger  *slog.Logger
}

func NewAdminFinanceHandler(service *services.AdminFinanceService, logger *slog.Logger) *AdminFinanceHandler {
	return &AdminFinanceHandler{service: service, logger: logger}
}

// ListPayments handles GET /api/v1/admin/payments.
func (h *AdminFinanceHandler) ListPayments(c *gin.Context) {
	raw := services.RawAdminPaymentQuery{
		Status: c.Query("status"), Provider: c.Query("provider"),
		DateFrom: c.Query("date_from"), DateTo: c.Query("date_to"),
		Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.ListPayments(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// ListCommissions handles GET /api/v1/admin/commissions.
func (h *AdminFinanceHandler) ListCommissions(c *gin.Context) {
	raw := services.RawAdminCommissionQuery{
		SellerID: c.Query("seller"), DateFrom: c.Query("date_from"), DateTo: c.Query("date_to"),
		Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.ListCommissions(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}
