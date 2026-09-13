package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// AdminOrderHandler is read-only in Stage 8 (§22): no order status
// mutation route exists here — see AdminOrderService's doc for why.
type AdminOrderHandler struct {
	service *services.AdminOrderService
	logger  *slog.Logger
}

func NewAdminOrderHandler(service *services.AdminOrderService, logger *slog.Logger) *AdminOrderHandler {
	return &AdminOrderHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/orders.
func (h *AdminOrderHandler) List(c *gin.Context) {
	raw := services.RawAdminOrderQuery{
		Status: c.Query("status"), UserID: c.Query("user"),
		DateFrom: c.Query("date_from"), DateTo: c.Query("date_to"),
		MinTotal: c.Query("min_total"), MaxTotal: c.Query("max_total"),
		Sort: c.Query("sort"), Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.List(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// Get handles GET /api/v1/admin/orders/:id.
func (h *AdminOrderHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	detail, err := h.service.GetDetail(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "ORDER_NOT_FOUND", "Order not found")
		return
	}
	response.Success(c, http.StatusOK, detail)
}
