package repositories

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/models"
)

// AdminPayoutRepository reads/mutates payouts marketplace-wide. The
// transactional primitives below (Begin/LockPayoutForUpdate/RefundSeller/
// SetStatus) are exposed to AdminPayoutService the same way OrderRepository
// exposes Begin/LoadCartLinesForUpdate to OrderService (Stage 6) — the
// service orchestrates the transaction and owns the transition-validity
// rule (Stage 8 §26/§39); the repository only provides locked primitives
// and executes SQL.
type AdminPayoutRepository struct {
	pool *pgxpool.Pool
}

func NewAdminPayoutRepository(pool *pgxpool.Pool) *AdminPayoutRepository {
	return &AdminPayoutRepository{pool: pool}
}

func (r *AdminPayoutRepository) Begin(ctx context.Context) (pgx.Tx, error) {
	return r.pool.Begin(ctx)
}

func (r *AdminPayoutRepository) List(ctx context.Context, q models.AdminPayoutQuery) ([]models.AdminPayoutItem, int, error) {
	where := "TRUE"
	var args []any
	if q.Status != "" {
		where = "p.status = $1"
		args = append(args, q.Status)
	}

	countQuery := "SELECT COUNT(*) FROM payouts p WHERE " + where
	var total int
	if err := r.pool.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count admin payouts: %w", err)
	}
	if total == 0 {
		return []models.AdminPayoutItem{}, 0, nil
	}

	listArgs := append(append([]any{}, args...), q.Limit, q.Offset)
	listQuery := fmt.Sprintf(`
		SELECT p.id, p.seller_id, s.name, p.amount::text, p.status, p.requested_at, p.processed_at
		FROM payouts p
		JOIN sellers s ON s.id = p.seller_id
		WHERE %s
		ORDER BY p.requested_at DESC, p.id DESC
		LIMIT $%d OFFSET $%d
	`, where, len(args)+1, len(args)+2)

	rows, err := r.pool.Query(ctx, listQuery, listArgs...)
	if err != nil {
		return nil, 0, fmt.Errorf("query admin payouts: %w", err)
	}
	defer rows.Close()

	items := []models.AdminPayoutItem{}
	for rows.Next() {
		var it models.AdminPayoutItem
		var amount string
		if err := rows.Scan(&it.ID, &it.SellerID, &it.SellerName, &amount, &it.Status, &it.RequestedAt, &it.ProcessedAt); err != nil {
			return nil, 0, fmt.Errorf("scan admin payout: %w", err)
		}
		it.Amount = models.Money(amount)
		items = append(items, it)
	}
	return items, total, rows.Err()
}

func (r *AdminPayoutRepository) GetByID(ctx context.Context, id int64) (*models.AdminPayoutItem, error) {
	row := r.pool.QueryRow(ctx, `
		SELECT p.id, p.seller_id, s.name, p.amount::text, p.status, p.requested_at, p.processed_at
		FROM payouts p
		JOIN sellers s ON s.id = p.seller_id
		WHERE p.id = $1
	`, id)
	var it models.AdminPayoutItem
	var amount string
	err := row.Scan(&it.ID, &it.SellerID, &it.SellerName, &amount, &it.Status, &it.RequestedAt, &it.ProcessedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("scan admin payout %d: %w", id, err)
	}
	it.Amount = models.Money(amount)
	return &it, nil
}

// PayoutForUpdate is the locked snapshot AdminPayoutService branches on.
type PayoutForUpdate struct {
	Status   models.PayoutStatus
	SellerID int64
	Amount   string
}

// LockPayoutForUpdate locks the payout row for the duration of the
// transaction and returns its current status/seller/amount. models.ErrNotFound
// if it doesn't exist.
func (r *AdminPayoutRepository) LockPayoutForUpdate(ctx context.Context, tx pgx.Tx, payoutID int64) (*PayoutForUpdate, error) {
	var p PayoutForUpdate
	err := tx.QueryRow(ctx, `SELECT status, seller_id, amount::text FROM payouts WHERE id = $1 FOR UPDATE`, payoutID).
		Scan(&p.Status, &p.SellerID, &p.Amount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, models.ErrNotFound
		}
		return nil, fmt.Errorf("lock payout %d: %w", payoutID, err)
	}
	return &p, nil
}

// RefundSellerBalance adds amount back to the seller's available_amount —
// used only on a transition into "rejected" (Stage 8 §27/§28). Locks the
// seller_balances row first, exactly like PayoutRepository.Create's own
// balance check, so a concurrent payout request against the same seller
// can never race this refund.
func (r *AdminPayoutRepository) RefundSellerBalance(ctx context.Context, tx pgx.Tx, sellerID int64, amount string) error {
	tag, err := tx.Exec(ctx, `
		UPDATE seller_balances SET available_amount = available_amount + $1, updated_at = NOW()
		WHERE seller_id = $2
	`, amount, sellerID)
	if err != nil {
		return fmt.Errorf("refund seller balance %d: %w", sellerID, err)
	}
	if tag.RowsAffected() == 0 {
		return fmt.Errorf("refund seller balance %d: no seller_balances row", sellerID)
	}
	return nil
}

// SetStatus updates the payout's status and, when setProcessedAt is true,
// stamps processed_at = NOW() (paid/rejected are terminal, so they always
// get one; "processing" is still in flight and does not).
func (r *AdminPayoutRepository) SetStatus(ctx context.Context, tx pgx.Tx, payoutID int64, status models.PayoutStatus, setProcessedAt bool) error {
	var err error
	if setProcessedAt {
		_, err = tx.Exec(ctx, `UPDATE payouts SET status = $1, processed_at = NOW() WHERE id = $2`, status, payoutID)
	} else {
		_, err = tx.Exec(ctx, `UPDATE payouts SET status = $1 WHERE id = $2`, status, payoutID)
	}
	if err != nil {
		return fmt.Errorf("set payout %d status to %s: %w", payoutID, status, err)
	}
	return nil
}
