package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

type PayoutRepository struct {
	pool *pgxpool.Pool
}

func NewPayoutRepository(pool *pgxpool.Pool) *PayoutRepository {
	return &PayoutRepository{pool: pool}
}

func scanPayout(row rowScanner) (models.Payout, error) {
	var (
		p      models.Payout
		amount string
	)
	err := row.Scan(&p.ID, &amount, &p.Status, &p.RequestedAt, &p.ProcessedAt)
	if err != nil {
		return p, err
	}
	p.Amount = models.Money(amount)
	return p, nil
}

// List returns a seller's payout history, newest first.
func (r *PayoutRepository) List(ctx context.Context, sellerID int64) ([]models.Payout, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT id, amount::text, status, requested_at, processed_at
		FROM payouts
		WHERE seller_id = $1
		ORDER BY requested_at DESC, id DESC
	`, sellerID)
	if err != nil {
		return nil, fmt.Errorf("list payouts for seller %d: %w", sellerID, err)
	}
	defer rows.Close()

	payouts := []models.Payout{}
	for rows.Next() {
		p, err := scanPayout(rows)
		if err != nil {
			return nil, fmt.Errorf("scan payout: %w", err)
		}
		payouts = append(payouts, p)
	}
	return payouts, rows.Err()
}

// FindIDByIdempotencyKey is the fast-path idempotent-replay check (Stage 7
// §24, same pattern as Stage 6 orders).
func (r *PayoutRepository) FindIDByIdempotencyKey(ctx context.Context, sellerID int64, key string) (*int64, error) {
	if key == "" {
		return nil, nil
	}
	var id int64
	err := r.pool.QueryRow(ctx, `SELECT id FROM payouts WHERE seller_id = $1 AND idempotency_key = $2`, sellerID, key).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("find payout by idempotency key: %w", err)
	}
	return &id, nil
}

// GetByID returns a single payout scoped to sellerID.
func (r *PayoutRepository) GetByID(ctx context.Context, sellerID, payoutID int64) (*models.Payout, error) {
	p, err := scanPayout(r.pool.QueryRow(ctx, `
		SELECT id, amount::text, status, requested_at, processed_at
		FROM payouts WHERE id = $1 AND seller_id = $2
	`, payoutID, sellerID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.NewNotFoundError("PAYOUT_NOT_FOUND", "Payout not found")
		}
		return nil, fmt.Errorf("load payout %d: %w", payoutID, err)
	}
	return &p, nil
}

// Create requests a payout against available_amount only (Stage 7 §21/
// §22 — pending_amount is never touched here). Transaction-safe: locks the
// seller_balances row, checks the balance, decrements it, and inserts the
// payout row all inside one transaction (§23), so two concurrent requests
// can never both succeed against the same balance (§53) and a failure
// leaves the balance untouched. Returns *models.ConflictError{Code:
// INSUFFICIENT_AVAILABLE_BALANCE} if the balance doesn't cover the
// request; the raw error from the INSERT is returned unwrapped so the
// caller can detect a concurrent duplicate idempotency key via
// IsUniqueViolation, exactly like Stage 6's order creation.
func (r *PayoutRepository) Create(ctx context.Context, sellerID int64, amount, idempotencyKey string) (int64, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return 0, fmt.Errorf("begin create-payout transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var available string
	err = tx.QueryRow(ctx, `
		SELECT available_amount::text FROM seller_balances WHERE seller_id = $1 FOR UPDATE
	`, sellerID).Scan(&available)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return 0, models.NewConflictError("INSUFFICIENT_AVAILABLE_BALANCE", "No available balance to pay out")
		}
		return 0, fmt.Errorf("lock seller balance for seller %d: %w", sellerID, err)
	}

	if moneyToCents(amount) > moneyToCents(available) {
		return 0, models.NewConflictError("INSUFFICIENT_AVAILABLE_BALANCE", fmt.Sprintf("Available balance is only %s", available))
	}

	if _, err := tx.Exec(ctx, `
		UPDATE seller_balances SET available_amount = available_amount - $1, updated_at = NOW() WHERE seller_id = $2
	`, amount, sellerID); err != nil {
		return 0, fmt.Errorf("decrement available balance for seller %d: %w", sellerID, err)
	}

	var payoutID int64
	err = tx.QueryRow(ctx, `
		INSERT INTO payouts (seller_id, amount, status, idempotency_key)
		VALUES ($1, $2, 'pending', $3)
		RETURNING id
	`, sellerID, amount, nullIfEmpty(idempotencyKey)).Scan(&payoutID)
	if err != nil {
		return 0, err // caller checks IsUniqueViolation(err)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, fmt.Errorf("commit create-payout transaction: %w", err)
	}
	return payoutID, nil
}
