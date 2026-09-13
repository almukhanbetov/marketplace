package repositories

// validOffersCTE is the single, centralized SQL definition of "a publicly
// purchasable seller offer" (Stage 3 §7/§41): the offer itself, its seller
// and its product must all be active, and its inventory must have stock.
// Every query that needs offer/price data — product list, product detail,
// the offers endpoint, seller products — builds on this exact CTE so the
// rule can never drift between endpoints.
//
//	valid_offers columns:
//	  offer_id, seller_id, product_id, sku, price, old_price, delivery_days,
//	  available_quantity, seller_name, seller_slug, seller_rating, seller_verified
const validOffersCTE = `
	valid_offers AS (
		SELECT
			so.id AS offer_id,
			so.seller_id,
			so.product_id,
			so.sku,
			so.price,
			so.old_price,
			so.delivery_days,
			i.available_quantity,
			s.name AS seller_name,
			s.slug AS seller_slug,
			s.rating AS seller_rating,
			s.is_verified AS seller_verified
		FROM seller_offers so
		JOIN sellers s ON s.id = so.seller_id AND s.is_active = TRUE
		JOIN products vp ON vp.id = so.product_id AND vp.is_active = TRUE
		JOIN inventory i ON i.seller_offer_id = so.id AND i.available_quantity > 0
		WHERE so.is_active = TRUE
	)
`

// bestOfferRankedCTE ranks each product's valid offers by the centralized
// "best offer" rule (Stage 3 §27): cheapest price first, then higher
// seller rating, then smaller offer id for a fully deterministic result.
const bestOfferRankedCTE = `
	ranked_offers AS (
		SELECT
			vo.*,
			ROW_NUMBER() OVER (
				PARTITION BY vo.product_id
				ORDER BY vo.price ASC, vo.seller_rating DESC, vo.offer_id ASC
			) AS rn
		FROM valid_offers vo
	),
	best_offers AS (
		SELECT * FROM ranked_offers WHERE rn = 1
	)
`

// offerAggCTE summarizes, per product, how many distinct sellers and the
// fastest delivery among its valid offers — used by the product list and
// detail endpoints (seller_count, min_delivery_days).
const offerAggCTE = `
	offer_agg AS (
		SELECT
			product_id,
			COUNT(DISTINCT seller_id) AS seller_count,
			MIN(delivery_days) AS min_delivery_days
		FROM valid_offers
		GROUP BY product_id
	)
`

// discountExpr computes an integer discount percent from a price/old_price
// pair, guarding against division by zero and against old_price <= price
// (Stage 3 §22): 0 unless old_price is set, positive, and greater than
// price.
func discountExpr(oldPriceCol, priceCol string) string {
	return `CASE
		WHEN ` + oldPriceCol + ` IS NOT NULL AND ` + oldPriceCol + ` > 0 AND ` + oldPriceCol + ` > ` + priceCol + `
		THEN ROUND((( ` + oldPriceCol + ` - ` + priceCol + `) / ` + oldPriceCol + `) * 100)
		ELSE 0
	END::int`
}
