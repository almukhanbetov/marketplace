package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type SellerHandler struct {
	service *services.SellerService
	logger  *slog.Logger
}

func NewSellerHandler(service *services.SellerService, logger *slog.Logger) *SellerHandler {
	return &SellerHandler{service: service, logger: logger}
}

// List handles GET /api/v1/sellers.
func (h *SellerHandler) List(c *gin.Context) {
	sellers, err := h.service.List(c.Request.Context())
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.Success(c, http.StatusOK, sellers)
}

// Get handles GET /api/v1/sellers/:id.
func (h *SellerHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}

	seller, err := h.service.GetByID(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, seller)
}

// ListProducts handles GET /api/v1/sellers/:id/products.
func (h *SellerHandler) ListProducts(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}

	result, err := h.service.ListProducts(c.Request.Context(), id, c.Query("limit"), c.Query("offset"))
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}

	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{
		Limit: result.Limit, Offset: result.Offset, Total: result.Total,
	})
}
