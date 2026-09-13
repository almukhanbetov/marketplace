package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AdminProductHandler struct {
	service *services.AdminProductService
	logger  *slog.Logger
}

func NewAdminProductHandler(service *services.AdminProductService, logger *slog.Logger) *AdminProductHandler {
	return &AdminProductHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/products.
func (h *AdminProductHandler) List(c *gin.Context) {
	raw := services.RawAdminProductQuery{
		Search: c.Query("search"), CategoryID: c.Query("category_id"), Status: c.Query("status"),
		Sort: c.Query("sort"), Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.List(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// Get handles GET /api/v1/admin/products/:id.
func (h *AdminProductHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	detail, err := h.service.GetDetail(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.Success(c, http.StatusOK, detail)
}

type adminProductImageRequest struct {
	URL       string `json:"url"`
	IsPrimary bool   `json:"is_primary"`
	SortOrder int    `json:"sort_order"`
}

type createAdminProductRequest struct {
	CategoryID    int64                      `json:"category_id"`
	Brand         string                     `json:"brand"`
	NameRU        string                     `json:"name_ru"`
	NameKK        string                     `json:"name_kk"`
	NameEN        string                     `json:"name_en"`
	DescriptionRU string                     `json:"description_ru"`
	DescriptionKK string                     `json:"description_kk"`
	DescriptionEN string                     `json:"description_en"`
	Slug          string                     `json:"slug"`
	IsActive      bool                       `json:"is_active"`
	Images        []adminProductImageRequest `json:"images"`
}

// toImageInputs preserves nil-ness: an absent/null "images" field in the
// request body means "leave images untouched" (nil), while an explicit
// "images": [] means "clear all images" (non-nil, empty) — the repository
// layer's Update distinguishes exactly these two cases.
func toImageInputs(images []adminProductImageRequest) []models.ProductImageInput {
	if images == nil {
		return nil
	}
	out := make([]models.ProductImageInput, len(images))
	for i, img := range images {
		out[i] = models.ProductImageInput{URL: img.URL, IsPrimary: img.IsPrimary, SortOrder: img.SortOrder}
	}
	return out
}

// Create handles POST /api/v1/admin/products.
func (h *AdminProductHandler) Create(c *gin.Context) {
	var req createAdminProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include category_id, brand, names, slug")
		return
	}
	id, err := h.service.Create(c.Request.Context(), models.CreateProductInput{
		CategoryID: req.CategoryID, Brand: req.Brand,
		NameRU: req.NameRU, NameKK: req.NameKK, NameEN: req.NameEN,
		DescriptionRU: req.DescriptionRU, DescriptionKK: req.DescriptionKK, DescriptionEN: req.DescriptionEN,
		Slug: req.Slug, IsActive: req.IsActive, Images: toImageInputs(req.Images),
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "CATEGORY_NOT_FOUND", "Category not found")
		return
	}
	response.Success(c, http.StatusCreated, gin.H{"id": id})
}

type updateAdminProductRequest struct {
	CategoryID    int64                      `json:"category_id"`
	Brand         string                     `json:"brand"`
	NameRU        string                     `json:"name_ru"`
	NameKK        string                     `json:"name_kk"`
	NameEN        string                     `json:"name_en"`
	DescriptionRU string                     `json:"description_ru"`
	DescriptionKK string                     `json:"description_kk"`
	DescriptionEN string                     `json:"description_en"`
	Slug          string                     `json:"slug"`
	IsActive      bool                       `json:"is_active"`
	Images        []adminProductImageRequest `json:"images"`
}

// Update handles PUT /api/v1/admin/products/:id.
func (h *AdminProductHandler) Update(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateAdminProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include category_id, brand, names, slug")
		return
	}
	err := h.service.Update(c.Request.Context(), id, models.UpdateProductInput{
		CategoryID: req.CategoryID, Brand: req.Brand,
		NameRU: req.NameRU, NameKK: req.NameKK, NameEN: req.NameEN,
		DescriptionRU: req.DescriptionRU, DescriptionKK: req.DescriptionKK, DescriptionEN: req.DescriptionEN,
		Slug: req.Slug, IsActive: req.IsActive, Images: toImageInputs(req.Images),
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}

type updateAdminProductStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// UpdateStatus handles PATCH /api/v1/admin/products/:id/status.
func (h *AdminProductHandler) UpdateStatus(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateAdminProductStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_active")
		return
	}
	if err := h.service.UpdateStatus(c.Request.Context(), id, req.IsActive); err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
