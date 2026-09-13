package response

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func newTestContext() (*gin.Context, *httptest.ResponseRecorder) {
	gin.SetMode(gin.TestMode)
	rec := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(rec)
	return c, rec
}

func TestSuccess(t *testing.T) {
	c, rec := newTestContext()
	Success(c, http.StatusOK, gin.H{"id": 1})

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}

	var body struct {
		Data map[string]int `json:"data"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if body.Data["id"] != 1 {
		t.Errorf("expected data.id=1, got %v", body.Data)
	}
}

func TestSuccessList(t *testing.T) {
	c, rec := newTestContext()
	SuccessList(c, http.StatusOK, []int{1, 2, 3}, Meta{Limit: 20, Offset: 0, Total: 3})

	var body struct {
		Data []int `json:"data"`
		Meta Meta  `json:"meta"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if len(body.Data) != 3 || body.Meta.Total != 3 {
		t.Errorf("unexpected list response: %+v", body)
	}
}

func TestError(t *testing.T) {
	c, rec := newTestContext()
	Error(c, http.StatusNotFound, "PRODUCT_NOT_FOUND", "Product not found")

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rec.Code)
	}

	var body struct {
		Error ErrorBody `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid JSON: %v", err)
	}
	if body.Error.Code != "PRODUCT_NOT_FOUND" {
		t.Errorf("expected code PRODUCT_NOT_FOUND, got %q", body.Error.Code)
	}
}
