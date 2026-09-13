// Package response provides a consistent JSON envelope for every API
// response so handlers never hand-roll their own shape. It never leaks
// SQL text, stack traces, credentials, or filesystem paths to the client.
package response

import "github.com/gin-gonic/gin"

// Meta carries pagination info for list responses.
type Meta struct {
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
	Total  int `json:"total"`
}

// ErrorBody is the shape of the "error" field in an error response.
type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Success writes { "data": <payload> }.
func Success(c *gin.Context, status int, data any) {
	c.JSON(status, gin.H{"data": data})
}

// SuccessList writes { "data": <items>, "meta": {...} }.
func SuccessList(c *gin.Context, status int, data any, meta Meta) {
	c.JSON(status, gin.H{"data": data, "meta": meta})
}

// Error writes { "error": { "code": ..., "message": ... } }.
// message must already be safe to show a client — never pass raw error
// strings from the database or filesystem here; log those separately and
// pass a fixed, user-facing message instead.
func Error(c *gin.Context, status int, code, message string) {
	c.JSON(status, gin.H{"error": ErrorBody{Code: code, Message: message}})
}
