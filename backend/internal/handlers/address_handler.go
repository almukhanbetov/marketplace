package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AddressHandler struct {
	service *services.AddressService
	logger  *slog.Logger
}

func NewAddressHandler(service *services.AddressService, logger *slog.Logger) *AddressHandler {
	return &AddressHandler{service: service, logger: logger}
}

type addressRequest struct {
	Title      string `json:"title"`
	City       string `json:"city"`
	Street     string `json:"street"`
	House      string `json:"house"`
	Apartment  string `json:"apartment"`
	PostalCode string `json:"postal_code"`
	IsDefault  bool   `json:"is_default"`
}

func (r addressRequest) toInput() models.AddressInput {
	return models.AddressInput{
		Title:      r.Title,
		City:       r.City,
		Street:     r.Street,
		House:      r.House,
		Apartment:  r.Apartment,
		PostalCode: r.PostalCode,
		IsDefault:  r.IsDefault,
	}
}

// List handles GET /api/v1/me/addresses.
func (h *AddressHandler) List(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	addresses, err := h.service.List(c.Request.Context(), userID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, addresses)
}

// Create handles POST /api/v1/me/addresses.
func (h *AddressHandler) Create(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}

	var req addressRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
		return
	}

	address, err := h.service.Create(c.Request.Context(), userID, req.toInput())
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusCreated, address)
}

// Update handles PUT /api/v1/me/addresses/:id.
func (h *AddressHandler) Update(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	addressID, ok := parseNamedPathID(c, "id", "INVALID_ADDRESS_ID")
	if !ok {
		return
	}

	var req addressRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Invalid request body")
		return
	}

	address, err := h.service.Update(c.Request.Context(), userID, addressID, req.toInput())
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, address)
}

// SetDefault handles PATCH /api/v1/me/addresses/:id/default.
func (h *AddressHandler) SetDefault(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	addressID, ok := parseNamedPathID(c, "id", "INVALID_ADDRESS_ID")
	if !ok {
		return
	}

	address, err := h.service.SetDefault(c.Request.Context(), userID, addressID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, address)
}

// Delete handles DELETE /api/v1/me/addresses/:id.
func (h *AddressHandler) Delete(c *gin.Context) {
	userID, ok := currentUserID(c)
	if !ok {
		return
	}
	addressID, ok := parseNamedPathID(c, "id", "INVALID_ADDRESS_ID")
	if !ok {
		return
	}

	if err := h.service.Delete(c.Request.Context(), userID, addressID); err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"deleted": true})
}
