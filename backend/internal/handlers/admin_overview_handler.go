package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

// AdminOverviewHandler and every other Admin*Handler in this package are
// DEVELOPMENT-ONLY: ADMIN ROUTES ARE NOT PRODUCTION-SECURE UNTIL AUTH/RBAC
// STAGE. There is no session/JWT/role check on any /api/v1/admin/* route
// yet — Stage 9 adds that. See routes.go's admin route group comment.
type AdminOverviewHandler struct {
	service *services.AdminOverviewService
	logger  *slog.Logger
}

func NewAdminOverviewHandler(service *services.AdminOverviewService, logger *slog.Logger) *AdminOverviewHandler {
	return &AdminOverviewHandler{service: service, logger: logger}
}

// GetSummary handles GET /api/v1/admin/overview.
func (h *AdminOverviewHandler) GetSummary(c *gin.Context) {
	summary, err := h.service.GetSummary(c.Request.Context())
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	response.Success(c, http.StatusOK, summary)
}
