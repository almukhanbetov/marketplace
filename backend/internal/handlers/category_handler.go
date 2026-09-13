package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type CategoryHandler struct {
	service *services.CategoryService
	logger  *slog.Logger
}

func NewCategoryHandler(service *services.CategoryService, logger *slog.Logger) *CategoryHandler {
	return &CategoryHandler{service: service, logger: logger}
}

// List handles GET /api/v1/categories.
func (h *CategoryHandler) List(c *gin.Context) {
	categories, err := h.service.List(c.Request.Context())
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.Success(c, http.StatusOK, categories)
}

// Get handles GET /api/v1/categories/:id.
func (h *CategoryHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}

	category, err := h.service.GetByID(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "CATEGORY_NOT_FOUND", "Category not found")
		return
	}
	response.Success(c, http.StatusOK, category)
}
