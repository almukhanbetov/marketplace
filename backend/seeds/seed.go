// Package seeds populates the database with a repeatable demo dataset for
// local development. It is not used by the running API server — only by
// cmd/seed.
package seeds

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/auth"
)

// DevPassword is the shared local-development password for every seeded
// account (Stage 9 §65) — deliberately the same for all of them so a
// developer only needs to remember one credential; never used outside a
// local/dev database. Documented in the README, never printed alongside a
// real secret.
const DevPassword = "NovaDev2026"

// sellerOfferPlan describes one seller_offer to create for a product.
type sellerOfferPlan struct {
	sellerSlug   string
	sku          string
	price        string
	oldPrice     string
	deliveryDays int
	available    int
	reserved     int
}

// Run seeds the database inside a single transaction: if anything fails,
// everything rolls back and no half-created demo data is left behind.
//
// Idempotency strategy: every entity with a natural business key (email,
// slug, or a composite unique constraint) is written with
// `INSERT ... ON CONFLICT (<key>) DO UPDATE ... RETURNING id`, so re-running
// the seed updates the same rows instead of duplicating them, and always
// returns the same IDs for building relations. Entities with no natural key
// suitable for upserting (orders and everything chained off an order) are
// instead guarded by an explicit existence check ("does this customer
// already have orders?") before insenrting — see seedDemoOrders.
func Run(ctx context.Context, pool *pgxpool.Pool) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback(ctx) // no-op after a successful Commit

	userIDByEmail, err := seedUsers(ctx, tx)
	if err != nil {
		return fmt.Errorf("seed users: %w", err)
	}

	sellerIDBySlug, err := seedSellers(ctx, tx, userIDByEmail)
	if err != nil {
		return fmt.Errorf("seed sellers: %w", err)
	}

	if err := seedSellerBalances(ctx, tx, sellerIDBySlug); err != nil {
		return fmt.Errorf("seed seller balances: %w", err)
	}

	categoryIDBySlug, err := seedCategories(ctx, tx)
	if err != nil {
		return fmt.Errorf("seed categories: %w", err)
	}

	productIDBySlug, err := seedProducts(ctx, tx, categoryIDBySlug)
	if err != nil {
		return fmt.Errorf("seed products: %w", err)
	}

	if err := seedProductImages(ctx, tx, productIDBySlug); err != nil {
		return fmt.Errorf("seed product images: %w", err)
	}

	offerIDs, offerCount, err := seedSellerOffersAndInventory(ctx, tx, productIDBySlug, sellerIDBySlug)
	if err != nil {
		return fmt.Errorf("seed seller offers/inventory: %w", err)
	}

	if err := seedAddresses(ctx, tx, userIDByEmail); err != nil {
		return fmt.Errorf("seed addresses: %w", err)
	}

	if err := seedFavorites(ctx, tx, userIDByEmail, productIDBySlug); err != nil {
		return fmt.Errorf("seed favorites: %w", err)
	}

	if err := seedCartsAndItems(ctx, tx, userIDByEmail, offerIDs); err != nil {
		return fmt.Errorf("seed carts: %w", err)
	}

	if err := seedReviews(ctx, tx, userIDByEmail, productIDBySlug); err != nil {
		return fmt.Errorf("seed reviews: %w", err)
	}

	if err := seedDemoOrders(ctx, tx, userIDByEmail, offerIDs, sellerIDBySlug); err != nil {
		return fmt.Errorf("seed demo orders: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}

	fmt.Printf("seed complete: %d users, %d sellers, %d categories, %d products, %d seller offers\n",
		len(userIDByEmail), len(sellerIDBySlug), len(categoryIDBySlug), len(productIDBySlug), offerCount)

	return nil
}

func seedUsers(ctx context.Context, tx pgx.Tx) (map[string]int64, error) {
	// Hashed once and reused for every seeded account — bcrypt is
	// deliberately slow (~150-250ms/call), and every seed user shares the
	// same DevPassword, so hashing it once up front instead of once per
	// user keeps `go run ./cmd/seed` fast (Stage 9 §65).
	passwordHash, err := auth.HashPassword(DevPassword)
	if err != nil {
		return nil, fmt.Errorf("hash dev password: %w", err)
	}

	ids := make(map[string]int64, len(users))
	for _, u := range users {
		var id int64
		err := tx.QueryRow(ctx, `
			INSERT INTO users (email, phone, full_name, password_hash, role, is_active)
			VALUES ($1, $2, $3, $4, $5, TRUE)
			ON CONFLICT (email) DO UPDATE SET
				full_name = EXCLUDED.full_name,
				password_hash = EXCLUDED.password_hash,
				role = EXCLUDED.role,
				updated_at = NOW()
			RETURNING id
		`, u.Email, u.Phone, u.FullName, passwordHash, u.Role).Scan(&id)
		if err != nil {
			return nil, fmt.Errorf("upsert user %s: %w", u.Email, err)
		}
		ids[u.Email] = id
	}
	return ids, nil
}

func seedSellers(ctx context.Context, tx pgx.Tx, userIDByEmail map[string]int64) (map[string]int64, error) {
	ids := make(map[string]int64, len(sellers))
	for _, s := range sellers {
		userID, ok := userIDByEmail[s.UserEmail]
		if !ok {
			return nil, fmt.Errorf("seller %s references unknown user email %s", s.Slug, s.UserEmail)
		}

		var id int64
		err := tx.QueryRow(ctx, `
			INSERT INTO sellers (user_id, name, slug, description, rating, review_count, is_verified, is_active)
			VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
			ON CONFLICT (slug) DO UPDATE SET
				name = EXCLUDED.name,
				description = EXCLUDED.description,
				rating = EXCLUDED.rating,
				review_count = EXCLUDED.review_count,
				is_verified = EXCLUDED.is_verified,
				updated_at = NOW()
			RETURNING id
		`, userID, s.Name, s.Slug, s.Description, s.Rating, s.ReviewCount, s.IsVerified).Scan(&id)
		if err != nil {
			return nil, fmt.Errorf("upsert seller %s: %w", s.Slug, err)
		}
		ids[s.Slug] = id
	}
	return ids, nil
}

func seedSellerBalances(ctx context.Context, tx pgx.Tx, sellerIDBySlug map[string]int64) error {
	for _, id := range sellerIDBySlug {
		_, err := tx.Exec(ctx, `
			INSERT INTO seller_balances (seller_id, pending_amount, available_amount)
			VALUES ($1, 0, 0)
			ON CONFLICT (seller_id) DO NOTHING
		`, id)
		if err != nil {
			return fmt.Errorf("upsert seller_balances for seller %d: %w", id, err)
		}
	}
	return nil
}

func seedCategories(ctx context.Context, tx pgx.Tx) (map[string]int64, error) {
	ids := make(map[string]int64, len(categories))

	// Root categories first, then children, so parent_id can be resolved.
	for _, c := range categories {
		if c.ParentSlug != "" {
			continue
		}
		id, err := upsertCategory(ctx, tx, c, nil)
		if err != nil {
			return nil, err
		}
		ids[c.Slug] = id
	}
	for _, c := range categories {
		if c.ParentSlug == "" {
			continue
		}
		parentID, ok := ids[c.ParentSlug]
		if !ok {
			return nil, fmt.Errorf("category %s references unknown parent %s", c.Slug, c.ParentSlug)
		}
		id, err := upsertCategory(ctx, tx, c, &parentID)
		if err != nil {
			return nil, err
		}
		ids[c.Slug] = id
	}

	return ids, nil
}

func upsertCategory(ctx context.Context, tx pgx.Tx, c categorySeed, parentID *int64) (int64, error) {
	var id int64
	err := tx.QueryRow(ctx, `
		INSERT INTO categories (parent_id, name_ru, name_kk, name_en, slug, sort_order, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, TRUE)
		ON CONFLICT (slug) DO UPDATE SET
			parent_id = EXCLUDED.parent_id,
			name_ru = EXCLUDED.name_ru,
			name_kk = EXCLUDED.name_kk,
			name_en = EXCLUDED.name_en,
			sort_order = EXCLUDED.sort_order,
			updated_at = NOW()
		RETURNING id
	`, parentID, c.NameRU, c.NameKK, c.NameEN, c.Slug, c.SortOrder).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("upsert category %s: %w", c.Slug, err)
	}
	return id, nil
}

func seedProducts(ctx context.Context, tx pgx.Tx, categoryIDBySlug map[string]int64) (map[string]int64, error) {
	ids := make(map[string]int64, len(products))
	for _, p := range products {
		categoryID, ok := categoryIDBySlug[p.CategorySlug]
		if !ok {
			return nil, fmt.Errorf("product %s references unknown category %s", p.Slug, p.CategorySlug)
		}

		descRU := fmt.Sprintf("%s — оригинальный товар от %s с гарантией и быстрой доставкой по Казахстану.", p.NameRU, p.Brand)
		descKK := fmt.Sprintf("%s — %s брендінің түпнұсқа тауары, кепілдікпен және Қазақстан бойынша жылдам жеткізумен.", p.NameKK, p.Brand)
		descEN := fmt.Sprintf("%s is an original product from %s, backed by warranty and fast delivery across Kazakhstan.", p.NameEN, p.Brand)

		var id int64
		err := tx.QueryRow(ctx, `
			INSERT INTO products (
				category_id, brand, name_ru, name_kk, name_en,
				description_ru, description_kk, description_en,
				slug, rating, review_count, is_active
			)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, TRUE)
			ON CONFLICT (slug) DO UPDATE SET
				category_id = EXCLUDED.category_id,
				brand = EXCLUDED.brand,
				name_ru = EXCLUDED.name_ru,
				name_kk = EXCLUDED.name_kk,
				name_en = EXCLUDED.name_en,
				description_ru = EXCLUDED.description_ru,
				description_kk = EXCLUDED.description_kk,
				description_en = EXCLUDED.description_en,
				rating = EXCLUDED.rating,
				review_count = EXCLUDED.review_count,
				updated_at = NOW()
			RETURNING id
		`, categoryID, p.Brand, p.NameRU, p.NameKK, p.NameEN, descRU, descKK, descEN,
			p.Slug, p.Rating, p.ReviewCount).Scan(&id)
		if err != nil {
			return nil, fmt.Errorf("upsert product %s: %w", p.Slug, err)
		}
		ids[p.Slug] = id
	}
	return ids, nil
}

func seedProductImages(ctx context.Context, tx pgx.Tx, productIDBySlug map[string]int64) error {
	for _, p := range products {
		productID := productIDBySlug[p.Slug]

		// Idempotent by construction: clear this product's images and
		// re-insert exactly two, rather than trying to upsert against a
		// key that doesn't exist for this purely-decorative table.
		if _, err := tx.Exec(ctx, `DELETE FROM product_images WHERE product_id = $1`, productID); err != nil {
			return fmt.Errorf("clear images for product %s: %w", p.Slug, err)
		}

		for i, suffix := range []string{"primary", "secondary"} {
			url := fmt.Sprintf("https://picsum.photos/seed/nova-%s-%s/600/600", p.Slug, suffix)
			_, err := tx.Exec(ctx, `
				INSERT INTO product_images (product_id, url, sort_order, is_primary)
				VALUES ($1, $2, $3, $4)
			`, productID, url, i, i == 0)
			if err != nil {
				return fmt.Errorf("insert image for product %s: %w", p.Slug, err)
			}
		}
	}
	return nil
}

// sellerSlugsInOrder mirrors the slug order in data.go's sellers slice, used
// to deterministically rotate through sellers when generating extra offers.
var sellerSlugsInOrder = func() []string {
	out := make([]string, len(sellers))
	for i, s := range sellers {
		out[i] = s.Slug
	}
	return out
}()

func indexOfSeller(slug string) int {
	for i, s := range sellerSlugsInOrder {
		if s == slug {
			return i
		}
	}
	return 0
}

// planOffersForProduct decides, deterministically from the product's
// position in the catalog, how many seller_offers it gets (1-3) and from
// which sellers — this is what guarantees several products end up with
// multiple different sellers, matching real marketplace behaviour.
func planOffersForProduct(index int, p productSeed) []sellerOfferPlan {
	primaryIdx := indexOfSeller(p.PrimarySellerSlug)
	n := sellerSlugsInOrder

	plans := []sellerOfferPlan{
		{
			sellerSlug:   p.PrimarySellerSlug,
			sku:          fmt.Sprintf("SKU-%03d-1", index+1),
			price:        p.Price,
			oldPrice:     p.OldPrice,
			deliveryDays: p.DeliveryDays,
			available:    5 + (index*7)%50,
			reserved:     index % 5,
		},
	}

	extraOffers := 0
	switch index % 3 {
	case 0:
		extraOffers = 2
	case 1:
		extraOffers = 1
	}

	multipliers := []struct{ price, old float64 }{
		{1.03, 1.03},
		{0.97, 0.97},
	}

	for i := 0; i < extraOffers; i++ {
		sellerIdx := (primaryIdx + 1 + i*2) % len(n)
		price := scaleMoney(p.Price, multipliers[i].price)
		oldPrice := scaleMoney(p.OldPrice, multipliers[i].old)
		plans = append(plans, sellerOfferPlan{
			sellerSlug:   n[sellerIdx],
			sku:          fmt.Sprintf("SKU-%03d-%d", index+1, i+2),
			price:        price,
			oldPrice:     oldPrice,
			deliveryDays: (p.DeliveryDays + i + 1) % 3,
			available:    5 + ((index+i+1)*11)%50,
			reserved:     (index + i) % 5,
		})
	}

	return plans
}

// scaleMoney multiplies a "123456.78"-formatted amount by factor and
// re-formats to 2 decimals, rounding to the nearest 100 KZT for a realistic
// price. Kept in fixed-point-ish integer arithmetic (cents) to avoid
// float64 rounding surprises creeping into seeded data.
func scaleMoney(amount string, factor float64) string {
	var whole, frac int64
	fmt.Sscanf(amount, "%d.%d", &whole, &frac)
	cents := whole*100 + frac
	scaled := int64(float64(cents) * factor)
	// round to nearest 10000 cents (= 100 KZT)
	rounded := (scaled + 5000) / 10000 * 10000
	return fmt.Sprintf("%d.%02d", rounded/100, rounded%100)
}

type offerRef struct {
	id        int64
	productID int64
	sellerID  int64
	price     string
}

func seedSellerOffersAndInventory(
	ctx context.Context, tx pgx.Tx,
	productIDBySlug, sellerIDBySlug map[string]int64,
) (map[string]offerRef, int, error) {
	offerByKey := make(map[string]offerRef) // key: productSlug|sellerSlug
	count := 0

	for index, p := range products {
		productID := productIDBySlug[p.Slug]
		plans := planOffersForProduct(index, p)

		for _, plan := range plans {
			sellerID := sellerIDBySlug[plan.sellerSlug]

			var offerID int64
			err := tx.QueryRow(ctx, `
				INSERT INTO seller_offers (seller_id, product_id, sku, price, old_price, delivery_days, is_active)
				VALUES ($1, $2, $3, $4, $5, $6, TRUE)
				ON CONFLICT (seller_id, sku) DO UPDATE SET
					price = EXCLUDED.price,
					old_price = EXCLUDED.old_price,
					delivery_days = EXCLUDED.delivery_days,
					updated_at = NOW()
				RETURNING id
			`, sellerID, productID, plan.sku, plan.price, plan.oldPrice, plan.deliveryDays).Scan(&offerID)
			if err != nil {
				return nil, 0, fmt.Errorf("upsert seller_offer %s: %w", plan.sku, err)
			}

			_, err = tx.Exec(ctx, `
				INSERT INTO inventory (seller_offer_id, available_quantity, reserved_quantity)
				VALUES ($1, $2, $3)
				ON CONFLICT (seller_offer_id) DO UPDATE SET
					available_quantity = EXCLUDED.available_quantity,
					reserved_quantity = EXCLUDED.reserved_quantity,
					updated_at = NOW()
			`, offerID, plan.available, plan.reserved)
			if err != nil {
				return nil, 0, fmt.Errorf("upsert inventory for offer %s: %w", plan.sku, err)
			}

			offerByKey[p.Slug+"|"+plan.sellerSlug] = offerRef{
				id: offerID, productID: productID, sellerID: sellerID, price: plan.price,
			}
			count++
		}
	}

	return offerByKey, count, nil
}
