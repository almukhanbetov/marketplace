// Package testutil provides a shared way for repository/handler tests to
// get a real PostgreSQL connection when one is configured, and to skip
// cleanly (not fail) when it isn't — so `go test ./...` still passes with
// zero configuration, and runs the full integration suite for real against
// the local dev database when DB_* / DATABASE_URL / FRONTEND_URL are set
// (exactly as they are when running via docker-compose).
package testutil

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/nova/marketplace-backend/internal/config"
)

// ConnectTestDB returns a pool connected to the configured database, or
// calls t.Skip if no database is configured/reachable. Tests using this
// never modify seed data — they only read.
func ConnectTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	cfg, err := config.Load()
	if err != nil {
		t.Skipf("skipping integration test: configuration not available (%v) — set DB_*/DATABASE_URL and FRONTEND_URL to run", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, cfg.ConnString())
	if err != nil {
		t.Skipf("skipping integration test: cannot create pool: %v", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		t.Skipf("skipping integration test: database not reachable: %v", err)
	}

	t.Cleanup(pool.Close)
	return pool
}
