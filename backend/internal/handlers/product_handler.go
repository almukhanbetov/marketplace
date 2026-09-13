package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/nova/marketplace-backend/internal/response"
	"github.com/nova/marketplace-backend/internal/services"
)

type ProductHandler struct {
	service *services.ProductService
	logger  *slog.Logger
}

func NewProductHandler(service *services.ProductService, logger *slog.Logger) *ProductHandler {
	return &ProductHandler{service: service, logger: logger}
}

// List handles GET /api/v1/products, with search/filter/sort/pagination —
// see services.ProductQueryParams for the full set of query params. This
// handler only extracts raw strings from the query string; ParseProductQuery
// (in the service layer) does all validation.
func (h *ProductHandler) List(c *gin.Context) {
	raw := services.ProductQueryParams{
		Search:     c.Query("search"),
		Category:   c.Query("category"),
		CategoryID: c.Query("category_id"),
		Seller:     c.Query("seller"),
		Brand:      c.Query("brand"),
		MinPrice:   c.Query("min_price"),
		MaxPrice:   c.Query("max_price"),
		Rating:     c.Query("rating"),
		Sort:       c.Query("sort"),
		Limit:      c.Query("limit"),
		Offset:     c.Query("offset"),
	}

	result, err := h.service.List(c.Request.Context(), raw)
	if err != nil {
		writeServiceError(c, h.logger, err, "", "")
		return
	}

	response.SuccessList(c, http.StatusOK, result.Items, response.Meta{
		Limit: result.Limit, Offset: result.Offset, Total: result.Total,
	})
}

// Get handles GET /api/v1/products/:id.
func (h *ProductHandler) Get(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}

	product, err := h.service.GetByID(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.Success(c, http.StatusOK, product)
}

// ListOffers handles GET /api/v1/products/:id/offers.
func (h *ProductHandler) ListOffers(c *gin.Context) {
	id, ok := parsePathID(c)
	if !ok {
		return
	}

	offers, err := h.service.ListOffers(c.Request.Context(), id)
	if err != nil {
		writeServiceError(c, h.logger, err, "PRODUCT_NOT_FOUND", "Product not found")
		return
	}
	response.Success(c, http.StatusOK, offers)
}
