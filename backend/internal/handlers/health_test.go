package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

type fakePinger struct {
	err error
}

func (f fakePinger) Ping(ctx context.Context) error {
	return f.err
}

func newTestLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}

func performHealthRequest(t *testing.T, h *HealthHandler) *httptest.ResponseRecorder {
	t.Helper()
	gin.SetMode(gin.TestMode)

	router := gin.New()
	router.GET("/health", h.Health)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	return rec
}

func TestHealth_DatabaseHealthy(t *testing.T) {
	h := NewHealthHandler(fakePinger{err: nil}, newTestLogger())
	rec := performHealthRequest(t, h)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("expected status=ok, got %q", body["status"])
	}
}

func TestHealth_DatabaseUnhealthy(t *testing.T) {
	h := NewHealthHandler(fakePinger{err: errors.New("connection refused")}, newTestLogger())
	rec := performHealthRequest(t, h)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status 503, got %d", rec.Code)
	}

	body := rec.Body.String()
	if strings.Contains(body, "connection refused") {
		t.Errorf("response must not leak the underlying error text, got: %s", body)
	}
}

func TestHealth_NilDatabase(t *testing.T) {
	h := NewHealthHandler(nil, newTestLogger())
	rec := performHealthRequest(t, h)

	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected status 503 for nil db, got %d", rec.Code)
	}
}
