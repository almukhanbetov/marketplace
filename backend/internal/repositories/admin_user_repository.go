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

type AdminUserRepository struct {
	pool *pgxpool.Pool
}

func NewAdminUserRepository(pool *pgxpool.Pool) *AdminUserRepository {
	return &AdminUserRepository{pool: pool}
}

var adminUserSortColumns = map[string]string{
	"":                "u.created_at DESC, u.id DESC",
	"created_at_asc":  "u.created_at ASC, u.id ASC",
	"created_at_desc": "u.created_at DESC, u.id DESC",
	"name_asc":        "u.full_name ASC, u.id ASC",
}

// List returns admin-safe user rows — password_hash is never selected at
// all (Stage 8 §6/§71).
func (r *AdminUserRepository) List(ctx context.Context, q models.UserQuery) ([]models.User, int, error) {
	var conditions []string
	var args []any
	next := func(v any) string {
		args = append(args, v)
		return fmt.Sprintf("$%d", len(args))
	}

	if q.Search != "" {
		p := next("%" + q.Search + "%")
		conditions = append(conditions, fmt.Sprintf("(u.full_name ILIKE %s OR u.email ILIKE %s OR u.phone ILIKE %s)", p, p, p))
	}
	if q.Role != "" {
		conditions = append(conditions, "u.role = "+next(q.Role))
	}
	if q.Status == "active" {
		conditions = append(conditions, "u.is_active = TRUE")
	} else if q.Status == "inactive" {
		conditions = append(conditions, "u.is_active = FALSE")
	}

	where := "TRUE"
	if len(conditions) > 0 {
		where = strings.Join(conditions, " AND ")
	}

	orderBy := adminUserSortColumns[q.Sort]
	if orderBy == "" {
		orderBy = adminUserSortColumns[""]
	}

	countQuery := "SELECT COUNT(*) FROM users u WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin users: %w", err)
	}
	if total == 0 {
		return []models.User{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT u.id, u.email, u.phone, u.full_name, u.role, u.is_active, u.created_at, u.updated_at
		FROM users u
		WHERE %s
		ORDER BY %s
		LIMIT $%d OFFSET $%d
	`, where, orderBy, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin users: %w", err)
	}
	defer rows.Close()

	users := []models.User{}
	for rows.Next() {
		var u models.User
		if err := rows.Scan(&u.ID, &u.Email, &u.Phone, &u.FullName, &u.Role, &u.IsActive, &u.CreatedAt, &u.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("scan admin user: %w", err)
		}
		users = append(users, u)
	}
	return users, total, rows.Err()
}

// GetDetail returns the admin-safe user plus useful aggregates. Returns
// models.ErrNotFound if the user doesn't exist.
func (r *AdminUserRepository) GetDetail(ctx context.Context, id int64) (*models.UserDetail, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT
			u.id, u.email, u.phone, u.full_name, u.role, u.is_active, u.created_at, u.updated_at,
			(SELECT COUNT(*) FROM orders WHERE user_id = u.id) AS orders_count,
			(SELECT COUNT(*) FROM favorites WHERE user_id = u.id) AS favorites_count,
			(SELECT COUNT(*) FROM addresses WHERE user_id = u.id) AS addresses_count,
			(SELECT id FROM sellers WHERE user_id = u.id) AS seller_id
		FROM users u
		WHERE u.id = $1
	`, id)

	var d models.UserDetail
	err := row.Scan(
		&d.ID, &d.Email, &d.Phone, &d.FullName, &d.Role, &d.IsActive, &d.CreatedAt, &d.UpdatedAt,
		&d.OrdersCount, &d.FavoritesCount, &d.AddressesCount, &d.SellerID,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin user detail %d: %w", id, err)
	}
	return &d, nil
}

// UpdateStatus flips is_active — never deletes the user or their history
// (Stage 8 §8). Returns models.ErrNotFound if the user doesn't exist.
func (r *AdminUserRepository) UpdateStatus(ctx context.Context, id int64, isActive bool) error {
	tag, err := r.pool.Exec(ctx, `UPDATE users SET is_active = $1, updated_at = NOW() WHERE id = $2`, isActive, id)
	if err != nil {
		return fmt.Errorf("update user status %d: %w", id, err)
	}
	if tag.RowsAffected() == 0 {
		return models.ErrNotFound
	}
	return nil
}
