package middleware

import (
	"crypto/rand"
	"encoding/hex"

	"github.com/gin-gonic/gin"
)

// RequestIDKey is the gin.Context key (and response header name) used to
// carry the per-request correlation ID.
const RequestIDHeader = "X-Request-ID"
const requestIDContextKey = "request_id"

// RequestID ensures every request has a correlation ID: it reuses the
// client-supplied X-Request-ID header when present, otherwise it generates
// one. The ID is stored on the context (for logging) and echoed back on the
// response header.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = generateRequestID()
		}

		c.Set(requestIDContextKey, id)
		c.Writer.Header().Set(RequestIDHeader, id)
		c.Next()
	}
}

// GetRequestID reads the request ID stored by RequestID middleware. It
// returns an empty string if called outside of a request that went through
// the middleware.
func GetRequestID(c *gin.Context) string {
	if v, ok := c.Get(requestIDContextKey); ok {
		if id, ok := v.(string); ok {
			return id
		}
	}
	return ""
}

func generateRequestID() string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		// crypto/rand failing is effectively impossible on any real target;
		// fall back to a fixed marker rather than panicking mid-request.
		return "unavailable"
	}
	return hex.EncodeToString(buf)
}
