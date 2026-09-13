package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type AdminSellerRepository struct {
	pool *pgxpool.Pool
}

func NewAdminSellerRepository(pool *pgxpool.Pool) *AdminSellerRepository {
	return &AdminSellerRepository{pool: pool}
}

var adminSellerSortColumns = map[string]string{
	"":                "s.created_at DESC, s.id DESC",
	"created_at_asc":  "s.created_at ASC, s.id ASC",
	"created_at_desc": "s.created_at DESC, s.id DESC",
	"rating_desc":     "s.rating DESC, s.id ASC",
	"name_asc":        "s.name ASC, s.id ASC",
}

func (r *AdminSellerRepository) List(ctx context.Context, q models.AdminSellerQuery) ([]models.AdminSellerListItem, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Search != "" {
		p := next("%" + q.Search + "%")
		conditions = append(conditions, fmt.Sprintf("(s.name ILIKE %s OR s.slug ILIKE %s)", p, p))
	}
	if q.Verified != nil {
		conditions = append(conditions, "s.is_verified = "+next(*q.Verified))
	}
	if q.Status == "active" {
		conditions = append(conditions, "s.is_active = TRUE")
	} else if q.Status == "inactive" {
		conditions = append(conditions, "s.is_active = FALSE")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	orderBy := adminSellerSortColumns[q.Sort]
	if orderBy == "" {
		orderBy = adminSellerSortColumns[""]
	}

	countQuery := "SELECT COUNT(*) FROM sellers s WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin sellers: %w", err)
	}
	if total == 0 {
		return []models.AdminSellerListItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT
			s.id, s.user_id, s.name, s.slug, s.rating::float8, s.review_count,
			s.is_verified, s.is_active, s.created_at,
			(SELECT COUNT(*) FROM seller_offers so WHERE so.seller_id = s.id AND so.is_active = TRUE) AS active_offer_count
		FROM sellers s
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, where, orderBy, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin sellers: %w", err)
	}
	defer rows.Close()

	items := []models.AdminSellerListItem{}
	for rows.Next() {
		var it models.AdminSellerListItem
		if err := rows.Scan(&it.ID, &it.UserID, &it.Name, &it.Slug, &it.Rating, &it.ReviewCount, &it.IsVerified, &it.IsActive, &it.CreatedAt, &it.ActiveOfferCount); err != nil {
			return nil, 0, fmt.Errorf("scan admin seller: %w", err)
		}
		items = append(items, it)
	}
	return items, total, rows.Err()
}

// GetDetail returns the full admin seller view: public fields, safe
// account summary, offer/inventory counts, and financial aggregates.
// Returns models.ErrNotFound if the seller doesn't exist.
func (r *AdminSellerRepository) GetDetail(ctx context.Context, id int64) (*models.AdminSellerDetail, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT
			s.id, s.user_id, s.name, s.slug, s.description, s.rating::float8, s.review_count,
			s.is_verified, s.is_active, s.created_at,
			u.email, u.phone, u.is_active,
			(SELECT COUNT(*) FROM seller_offers so WHERE so.seller_id = s.id) AS total_offer_count,
			(SELECT COUNT(*) FROM seller_offers so WHERE so.seller_id = s.id AND so.is_active = TRUE) AS active_offer_count,
			(SELECT COUNT(*) FROM seller_offers so JOIN inventory i ON i.seller_offer_id = so.id
				WHERE so.seller_id = s.id AND so.is_active = TRUE AND i.available_quantity <= $2) AS low_stock_offers,
			(SELECT COUNT(DISTINCT oi.order_id) FROM order_items oi WHERE oi.seller_id = s.id) AS order_count,
			COALESCE((SELECT SUM(oi.total_price) FROM order_items oi
				JOIN orders o ON o.id = oi.order_id WHERE oi.seller_id = s.id AND o.status NOT IN ('cancelled', 'returned')), 0)::text AS gross_sales,
			COALESCE((SELECT SUM(oi.commission_amount) FROM order_items oi
				JOIN orders o ON o.id = oi.order_id WHERE oi.seller_id = s.id AND o.status NOT IN ('cancelled', 'returned')), 0)::text AS commission_generated,
			COALESCE(sb.pending_amount::text, '0.00'),
			COALESCE(sb.available_amount::text, '0.00'),
			(SELECT COUNT(*) FROM payouts WHERE seller_id = s.id) AS payout_count
		FROM sellers s
		JOIN users u ON u.id = s.user_id
		LEFT JOIN seller_balances sb ON sb.seller_id = s.id
		WHERE s.id = $1
	`, id, models.LowStockThreshold)

	var (
		d          models.AdminSellerDetail
		grossSales string
		commission string
		pending    string
		available  string
	)
	err := row.Scan(
		&d.ID, &d.UserID, &d.Name, &d.Slug, &d.Description, &d.Rating, &d.ReviewCount,
		&d.IsVerified, &d.IsActive, &d.CreatedAt,
		&d.AccountEmail, &d.AccountPhone, &d.AccountIsActive,
		&d.TotalOfferCount, &d.ActiveOfferCount, &d.LowStockOffers,
		&d.OrderCount, &grossSales, &commission, &pending, &available, &d.PayoutCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin seller detail %d: %w", id, err)
	}
	d.GrossSales = models.Money(grossSales)
	d.CommissionGenerated = models.Money(commission)
	d.PendingBalance = models.Money(pending)
	d.AvailableBalance = models.Money(available)
	return &d, nil
}

// UpdateStatus flips is_active. Deactivating a seller does not delete
// offers — Stage 3's valid_offers CTE already requires sellers.is_active
// = TRUE, so their offers automatically disappear from the public catalog
// without any further action here (Stage 8 §11).
func (r *AdminSellerRepository) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	tag, err := r.pool.Exec(ctx, `UPDATE sellers SET is_active = $1, updated_at = NOW() WHERE id = $2`, isActive, id)
	if err != nil {
		return fmt.Errorf("update seller status %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}

func (r *AdminSellerRepository) UpdateVerification(ctx context.Context, id int64, isVerified bool) error {
	tag, err := r.pool.Exec(ctx, `UPDATE sellers SET is_verified = $1, updated_at = NOW() WHERE id = $2`, isVerified, id)
	if err != nil {
		return fmt.Errorf("update seller verification %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}
