package handlers

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
)

// writeServiceError maps a service-layer error to the right HTTP response:
//   - *models.ValidationError -> 400, using its own safe code/message
//   - *models.NotFoundError   -> 404, using its own safe code/message
//   - *models.ConflictError   -> 409, using its own safe code/message
//   - models.ErrNotFound      -> 404, using the caller-supplied code/message
//   - anything else           -> 500, generic message; the real error is
//     logged server-side only (Stage 1 §38: never leak SQL text, stack
//     traces or internals to the client)
func writeServiceError(c *gin.Context, logger *slog.Logger, err error, notFoundCode, notFoundMessage string) {
	var validationErr *models.ValidationError
	var notFoundErr *models.NotFoundError
	var conflictErr *models.ConflictError
	switch {
	case errors.As(err, &validationErr):
		response.Error(c, http.StatusBadRequest, validationErr.Code, validationErr.Message)
	case errors.As(err, &notFoundErr):
		response.Error(c, http.StatusNotFound, notFoundErr.Code, notFoundErr.Message)
	case errors.As(err, &conflictErr):
		response.Error(c, http.StatusConflict, conflictErr.Code, conflictErr.Message)
	case errors.Is(err, models.ErrNotFound):
		response.Error(c, http.StatusNotFound, notFoundCode, notFoundMessage)
	default:
		logger.Error("internal error", "path", c.Request.URL.Path, "error", err)
		response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error")
	}
}

// parsePathID parses a required numeric :id path param. Returns false and
// already wrote a 400 response if it isn't a positive integer.
func parsePathID(c *gin.Context) (int64, bool) {
	raw := c.Param("id")
	id, err := parseID(raw)
	if err != nil {
		response.Error(c, http.StatusBadRequest, "INVALID_ID", "id must be a positive integer")
		return 0, false
	}
	return id, true
}
