package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type AdminUserHandler struct {
	service *services.AdminUserService
	logger  *slog.Logger
}

func NewAdminUserHandler(service *services.AdminUserService, logger *slog.Logger) *AdminUserHandler {
	return &AdminUserHandler{service: service, logger: logger}
}

// List handles GET /api/v1/admin/users.
func (h *AdminUserHandler) List(c *gin.Context) {
	raw := services.RawAdminUserQuery{
		Search: c.Query("search"), Role: c.Query("role"), Status: c.Query("status"),
		Sort: c.Query("sort"), Limit: c.Query("limit"), Offset: c.Query("offset"),
	}
	result, err := h.service.List(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{Limit: result.Limit, Offset: result.Offset, Total: result.Total})
}

// Get handles GET /api/v1/admin/users/:id.
func (h *AdminUserHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	detail, err := h.service.GetDetail(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, detail)
}

type updateUserStatusRequest struct {
	IsActive bool `json:"is_active"`
}

// UpdateStatus handles PATCH /api/v1/admin/users/:id/status.
func (h *AdminUserHandler) UpdateStatus(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}
	var req updateUserStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include is_active")
		return
	}
	if err := h.service.UpdateStatus(c.Request.Context(), id, req.IsActive); err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, gin.H{"updated": true})
}
