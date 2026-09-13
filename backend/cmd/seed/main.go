// Command seed populates the database with a repeatable demo dataset
// (users, sellers, categories, products, seller offers, inventory,
// favorites, carts, reviews, a couple of demo orders). Intended for local
// development only — run it after `go run ./cmd/migrate up`.
//
// Usage:
//
//	go run ./cmd/seed
package main

import (
	"context"
	"log/slog"
	"os"

	"github.com/nova/marketplace-backend/internal/config"
	"github.com/nova/marketplace-backend/internal/database"
	"github.com/nova/marketplace-backend/seeds"
)

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	ctx := context.Background()

	pool, err := database.NewPool(ctx, cfg.ConnString(), cfg.DBConnectTimeout)
	if err != nil {
		logger.Error("connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := seeds.Run(ctx, pool); err != nil {
		logger.Error("seed failed", "error", err)
		os.Exit(1)
	}

	logger.Info("seed completed successfully")
}
