package models

// ProductCard is one item in a product list (GET /products) — enough for a
// frontend catalog card, priced from the marketplace's best available
// offer (see ProductFilter / the ProductService doc comment for the exact
// "best offer" rule).
type ProductCard struct {
	ID              int64         `json:"id"`
	Slug            string        `json:"slug"`
	Brand           string        `json:"brand"`
	Name            LocalizedText `json:"name"`
	Category        CategoryRef   `json:"category"`
	Rating          float64       `json:"rating"`
	ReviewCount     int           `json:"review_count"`
	PrimaryImage    *string       `json:"primary_image"`
	Price           Money         `json:"price"`
	OldPrice        *Money        `json:"old_price"`
	DiscountPercent int           `json:"discount_percent"`
	BestOfferID     int64         `json:"best_offer_id"`
	SellerName      string        `json:"seller_name"`
	SellerRating    float64       `json:"seller_rating"`
	SellerCount     int           `json:"seller_count"`
	MinDeliveryDays int           `json:"min_delivery_days"`
}

// ProductDetail is the full product page payload. It intentionally embeds
// only the single best offer, not the full offer list — that lives at
// GET /products/:id/offers so it isn't duplicated in every product-detail
// response.
type ProductDetail struct {
	ID          int64         `json:"id"`
	Slug        string        `json:"slug"`
	Brand       string        `json:"brand"`
	Name        LocalizedText `json:"name"`
	Description LocalizedText `json:"description"`
	Category    CategoryRef   `json:"category"`
	Rating      float64       `json:"rating"`
	ReviewCount int           `json:"review_count"`
	Images      []string      `json:"images"`
	BestOffer   *Offer        `json:"best_offer"`
	SellerCount int           `json:"seller_count"`
}

// SortOption is a whitelisted product sort value. Only these five strings
// are ever accepted from a client — never a raw column name.
type SortOption string

const (
	SortPriceAsc     SortOption = "price_asc"
	SortPriceDesc    SortOption = "price_desc"
	SortRatingDesc   SortOption = "rating_desc"
	SortNewest       SortOption = "newest"
	SortDiscountDesc SortOption = "discount_desc"
)

// ProductFilter is the fully validated, typed query the product list
// endpoint runs. It is built and validated once in the service layer from
// raw query params and handed to the repository as-is — the repository
// never sees a gin.Context or an unvalidated string.
type ProductFilter struct {
	Search       string // matched against name_ru/name_kk/name_en/brand
	CategorySlug string
	CategoryID   *int64
	SellerSlug   string
	SellerID     *int64
	Brand        string
	MinPrice     string // validated decimal string, e.g. "100000.00"; "" = unset
	MaxPrice     string
	MinRating    string // validated decimal string 0-5; "" = unset
	Sort         SortOption
	Limit        int
	Offset       int
}
