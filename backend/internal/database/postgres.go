// Package database owns the single pgxpool.Pool used by the whole
// application. There is exactly one pool, created once at startup and
// closed once at shutdown — handlers and repositories never open their own
// connections.
package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool creates and validates a PostgreSQL connection pool. It bounds the
// connect + ping attempt with timeout so a slow or unreachable database
// cannot hang application startup indefinitely.
func NewPool(ctx context.Context, connString string, timeout time.Duration) (*pgxpool.Pool, error) {
	connectCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	pool, err := pgxpool.New(connectCtx, connString)
	if err != nil {
		return nil, fmt.Errorf("create pgx pool: %w", err)
	}

	if err := pool.Ping(connectCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return pool, nil
}
