package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/response"
)

// RateLimit rejects requests beyond limiter's per-key budget, keyed by
// "action:client-ip" — a minimal, single-instance brute-force guard for
// the auth endpoints (Stage 9 §35). See auth.RateLimiter's doc comment for
// this design's documented limitations.
func RateLimit(limiter *auth.RateLimiter, action string) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := action + ":" + c.ClientIP()
		if !limiter.Allow(key) {
			response.Error(c, http.StatusTooManyRequests, "TOO_MANY_REQUESTS", "Too many attempts — please wait and try again")
			c.Abort()
			return
		}
		c.Next()
	}
}
