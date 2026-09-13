package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type CartHandler struct {
	service *services.CartService
	logger  *slog.Logger
}

func NewCartHandler(service *services.CartService, logger *slog.Logger) *CartHandler {
	return &CartHandler{service: service, logger: logger}
}

// addItemRequest is the POST /cart/items body. Only seller_offer_id and
// quantity are ever accepted — no price field exists here at all, so the
// backend has nothing to trust even if a client sent one (Stage 5 §12).
type addItemRequest struct {
	SellerOfferID int64 `json:"seller_offer_id"`
	Quantity      int   `json:"quantity"`
}

type updateItemRequest struct {
	Quantity int `json:"quantity"`
}

// Get handles GET /api/v1/me/cart.
func (h *CartHandler) Get(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	cart, err := h.service.Get(c.Request.Context(), userID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, cart)
}

// AddItem handles POST /api/v1/me/cart/items.
func (h *CartHandler) AddItem(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	var req addItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include seller_offer_id and quantity")
		return
	}

	cart, err := h.service.AddItem(c.Request.Context(), userID, req.SellerOfferID, req.Quantity)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, cart)
}

// UpdateItem handles PATCH /api/v1/me/cart/items/:itemId.
func (h *CartHandler) UpdateItem(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	itemID, ok := parseNamedPathID(c, "itemId", "INVALID_ITEM_ID")
	if !ok {
		return
	}

	var req updateItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include quantity")
		return
	}

	cart, err := h.service.UpdateItemQuantity(c.Request.Context(), userID, itemID, req.Quantity)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, cart)
}

// RemoveItem handles DELETE /api/v1/me/cart/items/:itemId.
func (h *CartHandler) RemoveItem(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	itemID, ok := parseNamedPathID(c, "itemId", "INVALID_ITEM_ID")
	if !ok {
		return
	}

	cart, err := h.service.RemoveItem(c.Request.Context(), userID, itemID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, cart)
}

// Clear handles DELETE /api/v1/me/cart.
func (h *CartHandler) Clear(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	cart, err := h.service.Clear(c.Request.Context(), userID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, cart)
}
