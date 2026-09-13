package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type FavoriteHandler struct {
	service *services.FavoriteService
	logger  *slog.Logger
}

func NewFavoriteHandler(service *services.FavoriteService, logger *slog.Logger) *FavoriteHandler {
	return &FavoriteHandler{service: service, logger: logger}
}

// List handles GET /api/v1/me/favorites.
func (h *FavoriteHandler) List(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	items, err := h.service.List(c.Request.Context(), userID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, items)
}

// Add handles POST /api/v1/me/favorites/:productId.
func (h *FavoriteHandler) Add(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	productID, ok := parseNamedPathID(c, "productId", "INVALID_PRODUCT_ID")
	if !ok {
		return
	}

	if err := h.service.Add(c.Request.Context(), userID, productID); err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"favorited": true})
}

// Remove handles DELETE /api/v1/me/favorites/:productId.
func (h *FavoriteHandler) Remove(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	productID, ok := parseNamedPathID(c, "productId", "INVALID_PRODUCT_ID")
	if !ok {
		return
	}

	if err := h.service.Remove(c.Request.Context(), userID, productID); err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"favorited": false})
}
