package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// SellerOrderHandler exposes seller orders READ-ONLY (Stage 7 §16/§17) —
// there is no status-mutation route because no per-seller
// fulfillment/suborder entity exists in the schema; see
// SellerOrderRepository's doc comment for the full reasoning.
type SellerOrderHandler struct {
	service *services.SellerOrderService
	logger  *slog.Logger
}

func NewSellerOrderHandler(service *services.SellerOrderService, logger *slog.Logger) *SellerOrderHandler {
	return &SellerOrderHandler{service: service, logger: logger}
}

// List handles GET /api/v1/seller/orders.
func (h *SellerOrderHandler) List(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	result, err := h.service.List(c.Request.Context(), sellerID, c.Query("limit"), c.Query("offset"))
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{
		Limit:  result.Limit,
		Offset: result.Offset,
		Total:  result.Total,
	})
}

// Get handles GET /api/v1/seller/orders/:orderId.
func (h *SellerOrderHandler) Get(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}
	orderID, ok := parseNamedPathID(c, "orderId", "INVALID_ORDER_ID")
	if !ok {
		return
	}

	order, err := h.service.GetDetail(c.Request.Context(), sellerID, orderID)
	if err != nil {
		writeServiceError(c, h.logger, err, "ORDER_NOT_FOUND", "Order not found")
		return
	}
	response.Success(c, http.StatusOK, order)
}
