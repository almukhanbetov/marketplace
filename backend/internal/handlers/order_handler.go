package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type OrderHandler struct {
	service *services.OrderService
	logger  *slog.Logger
}

func NewOrderHandler(service *services.OrderService, logger *slog.Logger) *OrderHandler {
	return &OrderHandler{service: service, logger: logger}
}

// createOrderRequest is the POST /orders body — only the user's choices,
// never prices/totals/items (Stage 6 §3/§4). The idempotency key may
// arrive either as a header (preferred) or this field; the handler prefers
// the header when both are present.
type createOrderRequest struct {
	AddressID       int64  `json:"address_id"`
	PaymentProvider string `json:"payment_provider"`
	IdempotencyKey  string `json:"idempotency_key"`
}

// Create handles POST /api/v1/me/orders.
func (h *OrderHandler) Create(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	var req createOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include address_id and payment_provider")
		return
	}

	idempotencyKey := c.GetHeader("Idempotency-Key")
	if idempotencyKey == "" {
		idempotencyKey = req.IdempotencyKey
	}

	order, err := h.service.CreateOrder(c.Request.Context(), userID, models.CreateOrderInput{
		AddressID:       req.AddressID,
		PaymentProvider: models.PaymentProvider(req.PaymentProvider),
		IdempotencyKey:  idempotencyKey,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusCreated, order)
}

// List handles GET /api/v1/me/orders.
func (h *OrderHandler) List(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	orders, err := h.service.GetOrders(c.Request.Context(), userID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, orders)
}

// Get handles GET /api/v1/me/orders/:orderId.
func (h *OrderHandler) Get(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	orderID, ok := parseNamedPathID(c, "orderId", "INVALID_ORDER_ID")
	if !ok {
		return
	}

	order, err := h.service.GetOrder(c.Request.Context(), userID, orderID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, order)
}
