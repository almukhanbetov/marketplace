package handlers

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// Pinger is the minimal capability HealthHandler needs from the database.
// *pgxpool.Pool already satisfies this, and tests can supply a fake without
// needing a real PostgreSQL connection.
type Pinger interface {
	Ping(ctx context.Context) error
}

const healthCheckTimeout = 3 * time.Second

// HealthHandler serves GET /health.
type HealthHandler struct {
	db     Pinger
	logger *slog.Logger
}

// NewHealthHandler builds a HealthHandler. db may be nil, in which case the
// endpoint always reports the database as unavailable rather than panicking.
func NewHealthHandler(db Pinger, logger *slog.Logger) *HealthHandler {
	return &HealthHandler{db: db, logger: logger}
}

// Health reports 200 {"status":"ok"} when the database is reachable, or 503
// {"status":"error","message":"database unavailable"} otherwise. The
// response never includes connection details or the underlying error text.
func (h *HealthHandler) Health(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), healthCheckTimeout)
	defer cancel()

	if h.db == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "message": "database unavailable"})
		return
	}

	if err := h.db.Ping(ctx); err != nil {
		h.logger.Error("health check: database ping failed", "error", err)
		c.JSON(http.StatusServiceUnavailable, gin.H{"status": "error", "message": "database unavailable"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
