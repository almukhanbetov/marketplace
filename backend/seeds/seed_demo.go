package seeds

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// customerEmails is the subset of users that act as buyers in the demo data
// (favorites, carts, reviews, orders).
var customerEmails = []string{"aigerim@example.com", "nurlan@example.com", "saltanat@example.com"}

func primaryOfferFor(p productSeed, offers map[string]offerRef) offerRef {
	return offers[p.Slug+"|"+p.PrimarySellerSlug]
}

type addressSeed struct {
	title, city, street, house, apartment, postalCode string
}

// customerAddresses gives each demo customer one default address. Keyed by
// email rather than a DB column, since a user may legitimately have several
// addresses (no natural single-column unique key to upsert against) —
// idempotency is handled by an existence check in seedAddresses instead.
var customerAddresses = map[string]addressSeed{
	"aigerim@example.com":  {title: "Дом", city: "Алматы", street: "ул. Достык", house: "89", apartment: "12", postalCode: "050000"},
	"nurlan@example.com":   {title: "Дом", city: "Астана", street: "ул. Кабанбай батыра", house: "17", apartment: "45", postalCode: "010000"},
	"saltanat@example.com": {title: "Офис", city: "Алматы", street: "пр. Аль-Фараби", house: "17", apartment: "", postalCode: "050059"},
}

func seedAddresses(ctx context.Context, tx pgx.Tx, userIDByEmail map[string]int64) error {
	for _, email := range customerEmails {
		userID := userIDByEmail[email]
		addr, ok := customerAddresses[email]
		if !ok {
			continue
		}

		var existing int
		if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM addresses WHERE user_id = $1`, userID).Scan(&existing); err != nil {
			return fmt.Errorf("count existing addresses for %s: %w", email, err)
		}
		if existing > 0 {
			continue // already seeded in a previous run
		}

		var apartment any
		if addr.apartment != "" {
			apartment = addr.apartment
		}

		_, err := tx.Exec(ctx, `
			INSERT INTO addresses (user_id, title, city, street, house, apartment, postal_code, is_default)
			VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
		`, userID, addr.title, addr.city, addr.street, addr.house, apartment, addr.postalCode)
		if err != nil {
			return fmt.Errorf("insert address for %s: %w", email, err)
		}
	}
	return nil
}

func seedFavorites(ctx context.Context, tx pgx.Tx, userIDByEmail, productIDBySlug map[string]int64) error {
	for custIdx, email := range customerEmails {
		userID := userIDByEmail[email]
		for k := 0; k < 5; k++ {
			p := products[(custIdx*7+k)%len(products)]
			productID := productIDBySlug[p.Slug]
			_, err := tx.Exec(ctx, `
				INSERT INTO favorites (user_id, product_id)
				VALUES ($1, $2)
				ON CONFLICT (user_id, product_id) DO NOTHING
			`, userID, productID)
			if err != nil {
				return fmt.Errorf("insert favorite user=%s product=%s: %w", email, p.Slug, err)
			}
		}
	}
	return nil
}

func seedCartsAndItems(ctx context.Context, tx pgx.Tx, userIDByEmail map[string]int64, offers map[string]offerRef) error {
	for custIdx, email := range customerEmails {
		userID := userIDByEmail[email]

		var cartID int64
		err := tx.QueryRow(ctx, `
			INSERT INTO carts (user_id)
			VALUES ($1)
			ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
			RETURNING id
		`, userID).Scan(&cartID)
		if err != nil {
			return fmt.Errorf("upsert cart for %s: %w", email, err)
		}

		for k := 0; k < 2; k++ {
			p := products[(custIdx*5+k)%len(products)]
			offer := primaryOfferFor(p, offers)
			quantity := 1 + k%2

			_, err := tx.Exec(ctx, `
				INSERT INTO cart_items (cart_id, seller_offer_id, quantity)
				VALUES ($1, $2, $3)
				ON CONFLICT (cart_id, seller_offer_id) DO UPDATE SET
					quantity = EXCLUDED.quantity,
					updated_at = NOW()
			`, cartID, offer.id, quantity)
			if err != nil {
				return fmt.Errorf("insert cart_item for %s / %s: %w", email, p.Slug, err)
			}
		}
	}
	return nil
}

func ratingToStars(rating string) int {
	var whole, frac int
	fmt.Sscanf(rating, "%d.%d", &whole, &frac)
	if frac >= 50 {
		whole++
	}
	if whole < 1 {
		return 1
	}
	if whole > 5 {
		return 5
	}
	return whole
}

func seedReviews(ctx context.Context, tx pgx.Tx, userIDByEmail, productIDBySlug map[string]int64) error {
	for index, p := range products {
		email := customerEmails[index%len(customerEmails)]
		userID := userIDByEmail[email]
		productID := productIDBySlug[p.Slug]

		stars := ratingToStars(p.Rating)
		snippets := reviewSnippets[stars]
		if len(snippets) == 0 {
			snippets = reviewSnippets[4]
		}
		text := snippets[index%len(snippets)]

		_, err := tx.Exec(ctx, `
			INSERT INTO reviews (product_id, user_id, rating, text, is_visible)
			VALUES ($1, $2, $3, $4, TRUE)
			ON CONFLICT (user_id, product_id) DO UPDATE SET
				rating = EXCLUDED.rating,
				text = EXCLUDED.text,
				updated_at = NOW()
		`, productID, userID, stars, text)
		if err != nil {
			return fmt.Errorf("insert review for %s / %s: %w", email, p.Slug, err)
		}
	}
	return nil
}

// commissionRate is the flat marketplace commission used for demo orders —
// mirrors the 10% used throughout the frontend's commission widget mock.
const commissionRate = "0.1000"

// seedDemoOrders creates one paid demo order per configured customer, each
// with two order_items (snapshotted from real seller_offers), a payment,
// per-item commissions, and updates the involved sellers' balances.
//
// Idempotency: guarded by an existence check rather than a natural key —
// orders are transactional records that legitimately accumulate, so "insert
// if this customer has none yet" is the right repeat-safe rule here rather
// than an upsert.
func seedDemoOrders(
	ctx context.Context, tx pgx.Tx,
	userIDByEmail map[string]int64, offers map[string]offerRef, sellerIDBySlug map[string]int64,
) error {
	plans := []struct {
		email     string
		productAt [2]int
	}{
		{email: "aigerim@example.com", productAt: [2]int{0, 9}},  // iPhone 17 Pro + MacBook Pro 14"
		{email: "nurlan@example.com", productAt: [2]int{20, 27}}, // Air Max Pulse + Loft sofa
	}

	for _, plan := range plans {
		userID := userIDByEmail[plan.email]

		var existing int
		if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM orders WHERE user_id = $1`, userID).Scan(&existing); err != nil {
			return fmt.Errorf("count existing orders for %s: %w", plan.email, err)
		}
		if existing > 0 {
			continue // already seeded in a previous run
		}

		type line struct {
			offer   offerRef
			product productSeed
			qty     int
		}
		lines := make([]line, 0, 2)
		for i, idx := range plan.productAt {
			p := products[idx]
			offer := primaryOfferFor(p, offers)
			lines = append(lines, line{offer: offer, product: p, qty: 1 + i%2})
		}

		subtotalCents := int64(0)
		type computed struct {
			line
			unitPrice, totalPrice, commissionAmount, sellerAmount int64
		}
		computedLines := make([]computed, 0, len(lines))
		for _, l := range lines {
			unit := parseCents(l.offer.price)
			total := unit * int64(l.qty)
			commission := total / 10 // 10%
			seller := total - commission
			subtotalCents += total
			computedLines = append(computedLines, computed{line: l, unitPrice: unit, totalPrice: total, commissionAmount: commission, sellerAmount: seller})
		}
		commissionTotalCents := int64(0)
		for _, cl := range computedLines {
			commissionTotalCents += cl.commissionAmount
		}
		totalCents := subtotalCents // no delivery/discount in this simple demo order

		var orderID int64
		err := tx.QueryRow(ctx, `
			INSERT INTO orders (user_id, status, subtotal, discount_total, delivery_total, commission_total, total, currency)
			VALUES ($1, 'paid', $2, 0, 0, $3, $4, 'KZT')
			RETURNING id
		`, userID, formatCents(subtotalCents), formatCents(commissionTotalCents), formatCents(totalCents)).Scan(&orderID)
		if err != nil {
			return fmt.Errorf("insert order for %s: %w", plan.email, err)
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO payments (order_id, provider, status, amount, currency, external_reference)
			VALUES ($1, 'kaspi_mock', 'paid', $2, 'KZT', $3)
		`, orderID, formatCents(totalCents), fmt.Sprintf("MOCK-%d", orderID))
		if err != nil {
			return fmt.Errorf("insert payment for order %d: %w", orderID, err)
		}

		for _, cl := range computedLines {
			var orderItemID int64
			err := tx.QueryRow(ctx, `
				INSERT INTO order_items (
					order_id, seller_id, product_id, seller_offer_id,
					product_name, sku, quantity, unit_price, total_price,
					commission_rate, commission_amount, seller_amount
				)
				VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
				RETURNING id
			`, orderID, cl.offer.sellerID, cl.offer.productID, cl.offer.id,
				cl.product.NameRU, fmt.Sprintf("SKU-ORDER-%d", cl.offer.id), cl.qty,
				formatCents(cl.unitPrice), formatCents(cl.totalPrice),
				commissionRate, formatCents(cl.commissionAmount), formatCents(cl.sellerAmount),
			).Scan(&orderItemID)
			if err != nil {
				return fmt.Errorf("insert order_item for order %d: %w", orderID, err)
			}

			_, err = tx.Exec(ctx, `
				INSERT INTO commissions (order_item_id, seller_id, rate, amount)
				VALUES ($1, $2, $3, $4)
			`, orderItemID, cl.offer.sellerID, commissionRate, formatCents(cl.commissionAmount))
			if err != nil {
				return fmt.Errorf("insert commission for order_item %d: %w", orderItemID, err)
			}

			_, err = tx.Exec(ctx, `
				UPDATE seller_balances
				SET available_amount = available_amount + $1, updated_at = NOW()
				WHERE seller_id = $2
			`, formatCents(cl.sellerAmount), cl.offer.sellerID)
			if err != nil {
				return fmt.Errorf("update seller_balance for seller %d: %w", cl.offer.sellerID, err)
			}
		}
	}

	// One demo payout, paid, for the first seller — exercises the payouts
	// table end to end. Guarded the same way: skip if this seller already
	// has a payout from a previous seed run.
	techstoreID := sellerIDBySlug["techstore"]
	var payoutCount int
	if err := tx.QueryRow(ctx, `SELECT COUNT(*) FROM payouts WHERE seller_id = $1`, techstoreID).Scan(&payoutCount); err != nil {
		return fmt.Errorf("count existing payouts: %w", err)
	}
	if payoutCount == 0 {
		_, err := tx.Exec(ctx, `
			INSERT INTO payouts (seller_id, amount, status, processed_at)
			VALUES ($1, 50000.00, 'paid', NOW())
		`, techstoreID)
		if err != nil {
			return fmt.Errorf("insert demo payout: %w", err)
		}
	}

	return nil
}

// parseCents / formatCents keep demo-order arithmetic in integer cents
// rather than float64, avoiding binary-float rounding error even for this
// seed-only code path.
func parseCents(amount string) int64 {
	var whole, frac int64
	fmt.Sscanf(amount, "%d.%d", &whole, &frac)
	return whole*100 + frac
}

func formatCents(cents int64) string {
	return fmt.Sprintf("%d.%02d", cents/100, cents%100)
}
