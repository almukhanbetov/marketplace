package handlers

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	authpkg "github.com/nova/marketplace-backend/internal/auth"
	"github.com/nova/marketplace-backend/internal/models"
	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

const refreshCookieName = "refresh_token"

// refreshCookiePath deliberately narrow (Stage 9 §32): the browser only
// ever attaches this cookie to the handful of endpoints that need it, not
// to every API call.
const refreshCookiePath = "/api/v1/auth"

// mobileClientHeader / mobileClientValue select the REFRESH-CREDENTIAL
// TRANSPORT, nothing more (Stage F2 §3/§49):
//
//   - browser (no/other X-Client): refresh token stays in an HttpOnly
//     SameSite cookie, never in a response body — unchanged from Stage 9.
//   - native app (X-Client: nova-mobile): refresh token is returned in
//     the JSON body so the app can put it in the OS keychain, and is
//     accepted back in the request body on refresh/logout.
//
// This header is NOT an authentication or authorization boundary. A
// browser could send it; doing so would only opt that request into
// body-transport of the refresh token (a worse XSS position for a
// browser, which is exactly why browsers must not). Every security
// check — signature, hash match, expiry, revocation, reuse detection,
// user-active — is identical regardless of transport and lives in
// AuthService, not here.
const (
	mobileClientHeader = "X-Client"
	mobileClientValue  = "nova-mobile"
)

func clientIsMobile(c *gin.Context) bool {
	return c.GetHeader(mobileClientHeader) == mobileClientValue
}

// mobileRefreshTokenBody is the {"refresh_token": "..."} shape a native
// client sends to /auth/refresh and /auth/logout instead of a cookie.
type mobileRefreshTokenBody struct {
	RefreshToken string `json:"refresh_token"`
}

// mobileAuthData builds the native login/register/refresh response body.
// `user` may be nil (refresh) — omitted from the payload when so.
func mobileAuthData(tokens *models.AuthTokens, user any) gin.H {
	data := gin.H{
		"access_token":       tokens.AccessToken,
		"access_expires_at":  tokens.AccessTokenExpires,
		"refresh_token":      tokens.RefreshToken,
		"refresh_expires_at": tokens.RefreshExpires,
	}
	if user != nil {
		data["user"] = user
	}
	return data
}

type AuthHandler struct {
	service      *services.AuthService
	logger       *slog.Logger
	cookieSecure bool
	cookieDomain string
}

func NewAuthHandler(service *services.AuthService, logger *slog.Logger, cookieSecure bool, cookieDomain string) *AuthHandler {
	return &AuthHandler{service: service, logger: logger, cookieSecure: cookieSecure, cookieDomain: cookieDomain}
}

func (h *AuthHandler) setRefreshCookie(c *gin.Context, tokens *models.AuthTokens) {
	maxAge := int(time.Until(tokens.RefreshExpires).Seconds())
	if maxAge <= 0 {
		maxAge = 30 * 24 * 60 * 60
	}
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie(refreshCookieName, tokens.RefreshToken, maxAge, refreshCookiePath, h.cookieDomain, h.cookieSecure, true)
}

func (h *AuthHandler) clearRefreshCookie(c *gin.Context) {
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie(refreshCookieName, "", -1, refreshCookiePath, h.cookieDomain, h.cookieSecure, true)
}

// noStore marks a response as never cached — every auth response carries
// credentials/identity and must not be stored by any intermediary or the
// browser's own cache (Stage 9 §62).
func noStore(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
}

// writeAuthError maps AuthService's auth-specific error codes to their
// correct HTTP status — 401 for anything meaning "you are not currently
// authenticated" (Stage 9 §11/§27), distinct from writeServiceError's
// generic 400 for ordinary validation errors. Falls through to
// writeServiceError for everything else (e.g. plain VALIDATION_ERROR,
// WEAK_PASSWORD, EMAIL_ALREADY_EXISTS).
func writeAuthError(c *gin.Context, logger *slog.Logger, err error) {
	if ve, ok := err.(*models.ValidationError); ok {
		switch ve.Code {
		case "INVALID_CREDENTIALS", "ACCOUNT_DISABLED", "SESSION_EXPIRED":
			response.Error(c, http.StatusUnauthorized, ve.Code, ve.Message)
			return
		}
	}
	writeServiceError(c, logger, err, "", "")
}

type registerRequest struct {
	Email    string `json:"email"`
	Phone    string `json:"phone"`
	FullName string `json:"full_name"`
	Password string `json:"password"`
}

// Register handles POST /api/v1/auth/register.
func (h *AuthHandler) Register(c *gin.Context) {
	noStore(c)
	var req registerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include full_name and password, plus email and/or phone")
		return
	}
	user, err := h.service.Register(c.Request.Context(), models.RegisterInput{
		Email: req.Email, Phone: req.Phone, FullName: req.FullName, Password: req.Password,
	})
	if err != nil {
		writeAuthError(c, h.logger, err)
		return
	}

	// Native clients get a ready-to-use session straight out of register
	// (Stage F2 §4/§22) — same as the web frontend's "auto-login after
	// signup", but done here so the app needs one round-trip, not two.
	// Web keeps its existing behaviour: just the created user, no tokens.
	if clientIsMobile(c) {
		identifier := req.Email
		if identifier == "" {
			identifier = req.Phone
		}
		userAgent := c.GetHeader("User-Agent")
		ip := c.ClientIP()
		_, tokens, loginErr := h.service.Login(c.Request.Context(), identifier, req.Password, &userAgent, &ip)
		if loginErr != nil {
			writeAuthError(c, h.logger, loginErr)
			return
		}
		detail, _ := h.service.Me(c.Request.Context(), user.ID)
		response.Success(c, http.StatusCreated, mobileAuthData(tokens, mobileUser(user, detail)))
		return
	}

	response.Success(c, http.StatusCreated, user)
}

// mobileUser prefers the fuller UserDetail (carries seller_id) and falls
// back to the plain User if the detail lookup failed for any reason.
func mobileUser(user *models.User, detail *models.UserDetail) any {
	if detail != nil {
		return detail
	}
	return user
}

type loginRequest struct {
	Email    string `json:"email"`
	Phone    string `json:"phone"`
	Password string `json:"password"`
}

// Login handles POST /api/v1/auth/login. Accepts either email or phone as
// the identifier (Stage 9 §10).
func (h *AuthHandler) Login(c *gin.Context) {
	noStore(c)
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.Error(c, http.StatusBadRequest, "VALIDATION_ERROR", "Request body must include password and email or phone")
		return
	}
	identifier := req.Email
	if identifier == "" {
		identifier = req.Phone
	}

	userAgent := c.GetHeader("User-Agent")
	ip := c.ClientIP()
	user, tokens, err := h.service.Login(c.Request.Context(), identifier, req.Password, &userAgent, &ip)
	if err != nil {
		writeAuthError(c, h.logger, err)
		return
	}

	if clientIsMobile(c) {
		// Native transport: refresh token in the body, no cookie.
		detail, _ := h.service.Me(c.Request.Context(), user.ID)
		response.Success(c, http.StatusOK, mobileAuthData(tokens, mobileUser(user, detail)))
		return
	}

	// Web transport: refresh token in the HttpOnly cookie only — never the
	// body (Stage 9 §3). Unchanged.
	h.setRefreshCookie(c, tokens)
	response.Success(c, http.StatusOK, gin.H{
		"user":         user,
		"access_token": tokens.AccessToken,
		"expires_at":   tokens.AccessTokenExpires,
	})
}

// Refresh handles POST /api/v1/auth/refresh.
//
//   - web: refresh token read solely from the HttpOnly cookie (Stage 9
//     §14 — never JS-readable). Unchanged.
//   - native (X-Client: nova-mobile): refresh token read from the JSON
//     body {"refresh_token": "..."}; the rotated token is returned in the
//     body; the cookie is never touched.
//
// Both paths call the identical AuthService.Refresh — same rotation, same
// reuse detection, same expiry/revocation/user-active checks.
func (h *AuthHandler) Refresh(c *gin.Context) {
	noStore(c)
	mobile := clientIsMobile(c)

	var raw string
	if mobile {
		var body mobileRefreshTokenBody
		_ = c.ShouldBindJSON(&body)
		raw = body.RefreshToken
	} else {
		raw, _ = c.Cookie(refreshCookieName)
	}

	userAgent := c.GetHeader("User-Agent")
	ip := c.ClientIP()
	tokens, err := h.service.Refresh(c.Request.Context(), raw, &userAgent, &ip)
	if err != nil {
		if !mobile {
			h.clearRefreshCookie(c)
		}
		writeAuthError(c, h.logger, err)
		return
	}

	if mobile {
		response.Success(c, http.StatusOK, mobileAuthData(tokens, nil))
		return
	}

	h.setRefreshCookie(c, tokens)
	response.Success(c, http.StatusOK, gin.H{
		"access_token": tokens.AccessToken,
		"expires_at":   tokens.AccessTokenExpires,
	})
}

// Logout handles POST /api/v1/auth/logout. Native clients send the
// refresh token in the body; web clients rely on the cookie. Both revoke
// exactly one session (AuthService.Logout is a no-op for a missing or
// already-invalid token, so a client can always safely call this).
func (h *AuthHandler) Logout(c *gin.Context) {
	noStore(c)
	mobile := clientIsMobile(c)

	var raw string
	if mobile {
		var body mobileRefreshTokenBody
		_ = c.ShouldBindJSON(&body)
		raw = body.RefreshToken
	} else {
		raw, _ = c.Cookie(refreshCookieName)
	}

	if err := h.service.Logout(c.Request.Context(), raw); err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	if !mobile {
		h.clearRefreshCookie(c)
	}
	response.Success(c, http.StatusOK, gin.H{"logged_out": true})
}

// LogoutAll handles POST /api/v1/auth/logout-all — requires RequireAuth.
func (h *AuthHandler) LogoutAll(c *gin.Context) {
	noStore(c)
	identity, ok := authpkg.IdentityFromContext(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	if err := h.service.LogoutAll(c.Request.Context(), identity.UserID); err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}
	if !clientIsMobile(c) {
		h.clearRefreshCookie(c)
	}
	response.Success(c, http.StatusOK, gin.H{"logged_out": true})
}

// Me handles GET /api/v1/auth/me — requires RequireAuth.
func (h *AuthHandler) Me(c *gin.Context) {
	noStore(c)
	identity, ok := authpkg.IdentityFromContext(c)
	if !ok {
		response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Authentication required")
		return
	}
	detail, err := h.service.Me(c.Request.Context(), identity.UserID)
	if err != nil {
		writeServiceError(c, h.logger, err, "USER_NOT_FOUND", "User not found")
		return
	}
	response.Success(c, http.StatusOK, detail)
}
