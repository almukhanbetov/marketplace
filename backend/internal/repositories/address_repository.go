package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type AddressRepository struct {
	pool *pgxpool.Pool
}

func NewAddressRepository(pool *pgxpool.Pool) *AddressRepository {
	return &AddressRepository{pool: pool}
}

const addressSelect = `id, user_id, title, city, street, house, apartment, postal_code, is_default`

func scanAddress(row rowScanner) (models.Address, error) {
	var a models.Address
	err := row.Scan(&a.ID, &a.UserID, &a.Title, &a.City, &a.Street, &a.House, &a.Apartment, &a.PostalCode, &a.IsDefault)
	return a, err
}

// List returns a user's addresses, default first.
func (r *AddressRepository) List(ctx context.Context, userID int64) ([]models.Address, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT `+addressSelect+`
		FROM addresses
		WHERE user_id = $1
		ORDER BY is_default DESC, id ASC
	`, userID)
	if err != nil {
		return nil, fmt.Errorf("query addresses for user %d: %w", userID, err)
	}
	defer rows.Close()

	addresses := []models.Address{}
	for rows.Next() {
		a, err := scanAddress(rows)
		if err != nil {
			return nil, fmt.Errorf("scan address: %w", err)
		}
		addresses = append(addresses, a)
	}
	return addresses, rows.Err()
}

// Create inserts a new address. If IsDefault is set, the user's previous
// default (if any) is cleared in the same transaction first — the
// partial-unique index on addresses(user_id) WHERE is_default guarantees
// at most one survives even under a race (Stage 5 §19).
func (r *AddressRepository) Create(ctx context.Context, userID int64, in models.AddressInput) (*models.Address, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin create-address transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	if in.IsDefault {
		if _, err := tx.Exec(ctx, `UPDATE addresses SET is_default = FALSE, updated_at = NOW() WHERE user_id = $1 AND is_default = TRUE`, userID); err != nil {
			return nil, fmt.Errorf("clear previous default address: %w", err)
		}
	}

	var id int64
	err = tx.QueryRow(ctx, `
		INSERT INTO addresses (user_id, title, city, street, house, apartment, postal_code, is_default)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id
	`, userID, nullIfEmpty(in.Title), in.City, in.Street, in.House, nullIfEmpty(in.Apartment), nullIfEmpty(in.PostalCode), in.IsDefault).Scan(&id)
	if err != nil {
		return nil, fmt.Errorf("insert address for user %d: %w", userID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit create-address transaction: %w", err)
	}

	return r.getByIDForUser(ctx, r.pool, userID, id)
}

// Update overwrites an existing address's fields, scoped to the requesting
// user. Same default-switching transaction as Create when IsDefault is set.
func (r *AddressRepository) Update(ctx context.Context, userID, addressID int64, in models.AddressInput) (*models.Address, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin update-address transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var owner int64
	err = tx.QueryRow(ctx, `SELECT user_id FROM addresses WHERE id = $1 FOR UPDATE`, addressID).Scan(&owner)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
		}
		return nil, fmt.Errorf("lookup address %d: %w", addressID, err)
	}
	if owner != userID {
		return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
	}

	if in.IsDefault {
		if _, err := tx.Exec(ctx, `UPDATE addresses SET is_default = FALSE, updated_at = NOW() WHERE user_id = $1 AND is_default = TRUE AND id != $2`, userID, addressID); err != nil {
			return nil, fmt.Errorf("clear previous default address: %w", err)
		}
	}

	_, err = tx.Exec(ctx, `
		UPDATE addresses
		SET title = $1, city = $2, street = $3, house = $4, apartment = $5, postal_code = $6, is_default = $7, updated_at = NOW()
		WHERE id = $8
	`, nullIfEmpty(in.Title), in.City, in.Street, in.House, nullIfEmpty(in.Apartment), nullIfEmpty(in.PostalCode), in.IsDefault, addressID)
	if err != nil {
		return nil, fmt.Errorf("update address %d: %w", addressID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit update-address transaction: %w", err)
	}

	return r.getByIDForUser(ctx, r.pool, userID, addressID)
}

// SetDefault flips one address to default and clears the user's previous
// default in the same transaction — a smaller, clearer operation than
// requiring a full field PUT just to change which address is default
// (Stage 5 §17 optional endpoint).
func (r *AddressRepository) SetDefault(ctx context.Context, userID, addressID int64) (*models.Address, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin set-default transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var owner int64
	err = tx.QueryRow(ctx, `SELECT user_id FROM addresses WHERE id = $1 FOR UPDATE`, addressID).Scan(&owner)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
		}
		return nil, fmt.Errorf("lookup address %d: %w", addressID, err)
	}
	if owner != userID {
		return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
	}

	if _, err := tx.Exec(ctx, `UPDATE addresses SET is_default = FALSE, updated_at = NOW() WHERE user_id = $1 AND is_default = TRUE AND id != $2`, userID, addressID); err != nil {
		return nil, fmt.Errorf("clear previous default address: %w", err)
	}
	if _, err := tx.Exec(ctx, `UPDATE addresses SET is_default = TRUE, updated_at = NOW() WHERE id = $1`, addressID); err != nil {
		return nil, fmt.Errorf("set default address %d: %w", addressID, err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("commit set-default transaction: %w", err)
	}

	return r.getByIDForUser(ctx, r.pool, userID, addressID)
}

// Delete removes an address, scoped to the requesting user — an address id
// belonging to another user is indistinguishable from a nonexistent one.
func (r *AddressRepository) Delete(ctx context.Context, userID, addressID int64) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM addresses WHERE id = $1 AND user_id = $2`, addressID, userID)
	if err != nil {
		return fmt.Errorf("delete address %d: %w", addressID, err)
	}
	if tag.RowsAffected() == 0 {
		return models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
	}
	return nil
}

// dbtx is the subset of pgxpool.Pool/pgx.Tx that getByIDForUser needs, so
// it can be reused after either a plain pool query or a just-committed
// transaction.
type dbtx interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func (r *AddressRepository) getByIDForUser(ctx context.Context, db dbtx, userID, addressID int64) (*models.Address, error) {
	a, err := scanAddress(db.QueryRow(ctx, `SELECT `+addressSelect+` FROM addresses WHERE id = $1 AND user_id = $2`, addressID, userID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("ADDRESS_NOT_FOUND", "Address not found")
		}
		return nil, fmt.Errorf("reload address %d: %w", addressID, err)
	}
	return &a, nil
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}
