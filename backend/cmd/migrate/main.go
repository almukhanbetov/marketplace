// Command migrate applies/inspects Goose SQL migrations against the
// configured database. It embeds Goose as a library (not a globally
// installed CLI) so migrations run identically via `go run ./cmd/migrate`
// locally, in CI, or inside the backend Docker image — no extra tool
// installation required.
//
// Usage:
//
//	go run ./cmd/migrate up
//	go run ./cmd/migrate down
//	go run ./cmd/migrate status
//	go run ./cmd/migrate redo
package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"os"

	// Registers the "pgx" driver with database/sql. Goose operates on a
	// stdlib *sql.DB; the rest of the application uses pgxpool directly.
	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"

	"github.com/nova/marketplace-backend/internal/config"
)

const migrationsDir = "migrations"

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: migrate <up|down|status|redo|up-by-one|version>")
		os.Exit(1)
	}
	command := os.Args[1]

	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	db, err := sql.Open("pgx", cfg.ConnString())
	if err != nil {
		logger.Error("open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		logger.Error("ping database", "error", err)
		os.Exit(1)
	}

	if err := goose.SetDialect("postgres"); err != nil {
		logger.Error("set goose dialect", "error", err)
		os.Exit(1)
	}

	if err := goose.RunContext(context.Background(), command, db, migrationsDir); err != nil {
		logger.Error("migration command failed", "command", command, "error", err)
		os.Exit(1)
	}

	logger.Info("migration command completed", "command", command)
}
