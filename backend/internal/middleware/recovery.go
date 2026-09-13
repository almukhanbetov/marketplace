package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
)

// Recovery recovers from any panic in a handler, logs the panic value and
// stack trace server-side, and returns a generic 500 to the client — the
// stack trace and panic value never reach the HTTP response.
func Recovery(logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if rec := recover(); rec != nil {
				logger.Error("panic recovered",
					"error", rec,
					"stack", string(debug.Stack()),
					"request_id", GetRequestID(c),
					"path", c.Request.URL.Path,
				)
				response.Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", "Internal server error")
				c.Abort()
			}
		}()
		c.Next()
	}
}
