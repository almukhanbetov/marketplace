package repositories

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
)

type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

// Exists reports whether an active user with this id exists. Stage 5 has no
// authentication yet — every user-scoped endpoint still validates the path
// userId refers to a real, active user before doing anything else.
func (r *UserRepository) Exists(ctx context.Context, id int64) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id = $1 AND is_active = TRUE)`, id).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("check user exists %d: %w", id, err)
	}
	return exists, nil
}
