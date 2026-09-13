package handlers

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/response"
)

// parseID validates a path/query id string is a positive integer.
func parseID(raw string) (int64, error) {
	id, err := strconv.ParseInt(raw, 10, 64)
	if err != nil || id <= 0 {
		return 0, fmt.Errorf("invalid id %q", raw)
	}
	return id, nil
}

// parseNamedPathID parses a required numeric :<name> path param. Returns
// false and already wrote a 400 response if it isn't a positive integer.
// Only used by routes that still take a path-scoped id (secondary ids
// like :orderId/:offerId/:itemId) — Stage 9 removed every route that took
// a caller-supplied :userId/:sellerId for a private operation.
func parseNamedPathID(c *gin.Context, name, errorCode string) (int64, bool) {
	id, err := parseID(c.Param(name))
	if err != nil {
		response.Error(c, http.StatusBadRequest, errorCode, name+" must be a positive integer")
		return 0, false
	}
	return id, true
}

// currentUserID returns the authenticated caller's user id from the
// request context RequireAuth attached — every /me/... handler uses this
// instead of trusting a URL param (Stage 9 §21). Writes a 401 and returns
// false if RequireAuth somehow didn't run (a routing bug, not a client
// error).
func currentUserID(c *gin.Context) (int64, bool) {
	identity, ok := auth.IdentityFromContext(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return 0, false
	}
	return identity.UserID, true
}

// currentSellerID returns the authenticated caller's linked active seller
// id. Requires RequireRole("seller") + RequireActiveSeller to have already
// run — those middlewares guarantee SellerID is non-nil by the time a
// handler using this is reached (Stage 9 §23/§24/§52).
func currentSellerID(c *gin.Context) (int64, bool) {
	identity, ok := auth.IdentityFromContext(c)
	if !ok || identity.SellerID == nil {
		response.Error(c, http.StatusForbidden, "FORBIDDEN", "No active seller account linked to this user")
		return 0, false
	}
	return *identity.SellerID, true
}
