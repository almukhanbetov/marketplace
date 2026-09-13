package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	authpkg "github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/repositories"
	"github.com/nova/marketplace-backend/internal/response"
)

// RequireAuth extracts and validates the Bearer access token, then
// reloads the user FRESH from the database — never trusting the JWT's own
// role/active claims beyond using them as a fast-fail hint — and attaches
// the resulting auth.Identity to the request context (Stage 9 §18/§19).
// A deactivated account is rejected here even if its access token hasn't
// expired yet (Stage 9 §12/§60).
func RequireAuth(jwtSecret string, authRepo *repositories.AuthRepository) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		const prefix = "Bearer "
		if !strings.HasPrefix(header, prefix) {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			c.Abort()
			return
		}
		tokenString := strings.TrimSpace(strings.TrimPrefix(header, prefix))

		claims, err := authpkg.ParseAccessToken(jwtSecret, tokenString)
		if err != nil {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired session")
			c.Abort()
			return
		}

		user, err := authRepo.GetUserByID(c.Request.Context(), claims.UserID)
		if err != nil {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired session")
			c.Abort()
			return
		}
		if !user.IsActive {
			response.Error(c, http.StatusUnauthorized, "ACCOUNT_DISABLED", "This account has been disabled")
			c.Abort()
			return
		}

		identity := authpkg.Identity{UserID: user.ID, Role: user.Role, IsActive: user.IsActive}
		if user.Role == "seller" {
			sellerID, err := authRepo.ActiveSellerIDForUser(c.Request.Context(), user.ID)
			if err == nil {
				identity.SellerID = sellerID
			}
		}
		authpkg.SetIdentity(c, identity)
		c.Next()
	}
}

// RequireRole allows only the exact given role through. Must run after
// RequireAuth. Returns 403 (not 404) for an authenticated caller with the
// wrong role (Stage 9 §20/§27).
func RequireRole(role string) gin.HandlerFunc {
	return RequireAnyRole(role)
}

// RequireAnyRole allows any of the given roles through.
func RequireAnyRole(roles ...string) gin.HandlerFunc {
	allowed := make(map[string]bool, len(roles))
	for _, r := range roles {
		allowed[r] = true
	}
	return func(c *gin.Context) {
		identity, ok := authpkg.IdentityFromContext(c)
		if !ok {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
			c.Abort()
			return
		}
		if !allowed[identity.Role] {
			response.Error(c, http.StatusForbidden, "FORBIDDEN", "You don't have permission to access this resource")
			c.Abort()
			return
		}
		c.Next()
	}
}

// RequireActiveSeller must run after RequireRole("seller") — it rejects a
// seller-role user whose linked sellers row is missing or deactivated
// (Stage 9 §24/§61). Public seller pages are unaffected — they never go
// through this middleware.
func RequireActiveSeller() gin.HandlerFunc {
	return func(c *gin.Context) {
		identity, ok := authpkg.IdentityFromContext(c)
		if !ok || identity.SellerID == nil {
			response.Error(c, http.StatusForbidden, "FORBIDDEN", "No active seller account linked to this user")
			c.Abort()
			return
		}
		c.Next()
	}
}
