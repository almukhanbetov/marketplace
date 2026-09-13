package auth

import "github.com/gin-gonic/gin"

const identityContextKey = "auth.identity"

// Identity is everything a handler is allowed to trust about the caller —
// resolved fresh from the database by RequireAuth on every request, never
// read directly off the JWT (Stage 9 §18/§19/§60). SellerID is non-nil
// only when Role == "seller" AND the linked sellers row is currently
// active; a deactivated seller account looks identical to "no seller
// account" to every seller-private handler.
type Identity struct {
	UserID   int64
	Role     string
	IsActive bool
	SellerID *int64
}

// SetIdentity stores the authenticated identity on the request context.
// Called only by RequireAuth.
func SetIdentity(c *gin.Context, id Identity) {
	c.Set(identityContextKey, id)
}

// IdentityFromContext retrieves the identity RequireAuth attached to this
// request. The bool is false if RequireAuth never ran (a handler bug, not
// a client error) — callers on an authenticated route can treat that as
// an internal error.
func IdentityFromContext(c *gin.Context) (Identity, bool) {
	v, ok := c.Get(identityContextKey)
	if !ok {
		return Identity{}, false
	}
	id, ok := v.(Identity)
	return id, ok
}
