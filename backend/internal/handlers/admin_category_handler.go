package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AdminCategoryHandler struct {
	service *services.AdminCategoryService
	logger  *slog.Logger
}

func NewAdminCategoryHandler(service *services.AdminCategoryService, logger *slog.Logger) *AdminCategoryHandler {
	return &AdminCategoryHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/categories.
func (h *AdminCategoryHandler) List(c *gin.Context) {
	categories, err := h.service.ListAll(c.Request.Context())
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.Success(c, http.StatusOK, categories)
}

type adminCategoryRequest struct {
	ParentID  *int64 `json:"parent_id"`
	NameRU    string `json:"name_ru"`
	NameKK    string `json:"name_kk"`
	NameEN    string `json:"name_en"`
	Slug      string `json:"slug"`
	ImageURL  string `json:"image_url"`
	SortOrder int    `json:"sort_order"`
	IsActive  bool   `json:"is_active"`
}

// Create handles POST /api/v1/admin/categories.
func (h *AdminCategoryHandler) Create(c *gin.Context) {
	var req adminCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include names and slug")
		return
	}
	id, err := h.service.Create(c.Request.Context(), models.CreateCategoryInput{
		ParentID: req.ParentID, NameRU: req.NameRU, NameKK: req.NameKK, NameEN: req.NameEN,
		Slug: req.Slug, ImageURL: req.ImageURL, SortOrder: req.SortOrder, IsActive: req.IsActive,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "CATEGORY_NOT_FOUND", "Parent category not found")
		return
	}
	response.Success(c, http.StatusCreated, gin.H{"id": id})
}

// Update handles PUT /api/v1/admin/categories/:id.
func (h *AdminCategoryHandler) Update(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req adminCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include names and slug")
		return
	}
	err := h.service.Update(c.Request.Context(), id, models.UpdateCategoryInput{
		ParentID: req.ParentID, NameRU: req.NameRU, NameKK: req.NameKK, NameEN: req.NameEN,
		Slug: req.Slug, ImageURL: req.ImageURL, SortOrder: req.SortOrder,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "CATEGORY_NOT_FOUND", "Category not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}

type updateCategoryStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// UpdateStatus handles PATCH /api/v1/admin/categories/:id/status.
func (h *AdminCategoryHandler) UpdateStatus(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateCategoryStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_active")
		return
	}
	if err := h.service.UpdateStatus(c.Request.Context(), id, req.IsActive); err != nil {
		writeServiceError(c, h.logger, err, "CATEGORY_NOT_FOUND", "Category not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
