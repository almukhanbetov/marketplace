package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// SellerOfferHandler covers both /seller/offers... and
// /seller/inventory... routes — consolidated the same way as
// SellerOfferRepository/SellerOfferService, since both resources are the
// same 1:1-joined data (Stage 7 §27 allows logical consolidation). The
// seller id always comes from the authenticated caller (Stage 9 §23).
type SellerOfferHandler struct {
	service *services.SellerOfferService
	logger  *slog.Logger
}

func NewSellerOfferHandler(service *services.SellerOfferService, logger *slog.Logger) *SellerOfferHandler {
	return &SellerOfferHandler{service: service, logger: logger}
}

// List handles GET /api/v1/seller/offers.
func (h *SellerOfferHandler) List(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	raw := services.RawSellerOfferQuery{
		Search:   c.Query("search"),
		Status:   c.Query("status"),
		LowStock: c.Query("low_stock"),
		Sort:     c.Query("sort"),
		Limit:    c.Query("limit"),
		Offset:   c.Query("offset"),
	}

	result, err := h.service.List(c.Request.Context(), sellerID, raw)
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

// createOfferRequest is the POST /offers body (Stage 7 §7) — the seller
// picks an existing catalog product and sets only these fields.
type createOfferRequest struct {
	ProductID    int64  `json:"product_id"`
	SKU          string `json:"sku"`
	Price        string `json:"price"`
	OldPrice     string `json:"old_price"`
	DeliveryDays int    `json:"delivery_days"`
	Stock        int    `json:"stock"`
}

// Create handles POST /api/v1/seller/offers.
func (h *SellerOfferHandler) Create(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	var req createOfferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include product_id, sku, price, delivery_days, stock")
		return
	}

	id, err := h.service.Create(c.Request.Context(), sellerID, models.CreateOfferInput{
		ProductID:    req.ProductID,
		SKU:          req.SKU,
		Price:        req.Price,
		OldPrice:     req.OldPrice,
		DeliveryDays: req.DeliveryDays,
		Stock:        req.Stock,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusCreated, gin.H{"id": id})
}

// updateOfferRequest is the PUT /offers/:offerId body (Stage 7 §8) — sku,
// price, old_price, delivery_days only; seller_id/product_id can never be
// reassigned this way.
type updateOfferRequest struct {
	SKU          string `json:"sku"`
	Price        string `json:"price"`
	OldPrice     string `json:"old_price"`
	DeliveryDays int    `json:"delivery_days"`
}

// Update handles PUT /api/v1/seller/offers/:offerId.
func (h *SellerOfferHandler) Update(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}
	offerID, ok := parseNamedPathID(c, "offerId", "INVALID_OFFER_ID")
	if !ok {
		return
	}

	var req updateOfferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include sku, price, delivery_days")
		return
	}

	err := h.service.Update(c.Request.Context(), sellerID, offerID, models.UpdateOfferInput{
		SKU:          req.SKU,
		Price:        req.Price,
		OldPrice:     req.OldPrice,
		DeliveryDays: req.DeliveryDays,
	})
	if err != nil {
		writeServiceError(c, h.logger, err, "OFFER_NOT_FOUND", "Offer not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}

type updateOfferStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// UpdateStatus handles PATCH /api/v1/seller/offers/:offerId/status.
func (h *SellerOfferHandler) UpdateStatus(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}
	offerID, ok := parseNamedPathID(c, "offerId", "INVALID_OFFER_ID")
	if !ok {
		return
	}

	var req updateOfferStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_active")
		return
	}

	if err := h.service.UpdateStatus(c.Request.Context(), sellerID, offerID, req.IsActive); err != nil {
		writeServiceError(c, h.logger, err, "OFFER_NOT_FOUND", "Offer not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}

// ListInventory handles GET /api/v1/seller/inventory.
func (h *SellerOfferHandler) ListInventory(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}

	items, err := h.service.ListInventory(c.Request.Context(), sellerID)
	if err != nil {
		writeServiceError(c, h.logger, err, "SELLER_NOT_FOUND", "Seller not found")
		return
	}
	response.Success(c, http.StatusOK, items)
}

type updateInventoryRequest struct {
	AvailableQuantity int `json:"available_quantity"`
}

// UpdateInventory handles PATCH /api/v1/seller/inventory/:offerId.
func (h *SellerOfferHandler) UpdateInventory(c *gin.Context) {
	sellerID, ok := currentSellerID(c)
	if !ok {
		return
	}
	offerID, ok := parseNamedPathID(c, "offerId", "INVALID_OFFER_ID")
	if !ok {
		return
	}

	var req updateInventoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include available_quantity")
		return
	}

	if err := h.service.UpdateInventory(c.Request.Context(), sellerID, offerID, req.AvailableQuantity); err != nil {
		writeServiceError(c, h.logger, err, "OFFER_NOT_FOUND", "Offer not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
