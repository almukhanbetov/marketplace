package config

import "testing"

func clearEnv(t *testing.T) {
	t.Helper()
	keys := []string{
		"APP_ENV", "PORT",
		"DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_SSLMODE",
		"DATABASE_URL", "FRONTEND_URL",
	}
	for _, k := range keys {
		t.Setenv(k, "")
	}
}

func TestLoad_ValidWithDatabaseURL(t *testing.T) {
	clearEnv(t)
	t.Setenv("FRONTEND_URL", "http://localhost:3000")
	t.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db?sslmode=disable")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected valid config, got error: %v", err)
	}
	if cfg.Port != defaultPort {
		t.Errorf("expected default port %q, got %q", defaultPort, cfg.Port)
	}
	if cfg.ConnString() != "postgres://user:pass@localhost:5432/db?sslmode=disable" {
		t.Errorf("expected ConnString to return DATABASE_URL verbatim, got %q", cfg.ConnString())
	}
}

func TestLoad_ValidWithDiscreteDBVars(t *testing.T) {
	clearEnv(t)
	t.Setenv("FRONTEND_URL", "http://localhost:3000")
	t.Setenv("DB_HOST", "localhost")
	t.Setenv("DB_PORT", "5432")
	t.Setenv("DB_NAME", "marketplace")
	t.Setenv("DB_USER", "postgres")
	t.Setenv("DB_PASSWORD", "postgres")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("expected valid config, got error: %v", err)
	}
	want := "postgres://postgres:postgres@localhost:5432/marketplace?sslmode=disable"
	if got := cfg.ConnString(); got != want {
		t.Errorf("ConnString() = %q, want %q", got, want)
	}
}

func TestLoad_MissingFrontendURL(t *testing.T) {
	clearEnv(t)
	t.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db")

	if _, err := Load(); err == nil {
		t.Fatal("expected error when FRONTEND_URL is missing, got nil")
	}
}

func TestLoad_MissingDatabaseConfig(t *testing.T) {
	clearEnv(t)
	t.Setenv("FRONTEND_URL", "http://localhost:3000")

	if _, err := Load(); err == nil {
		t.Fatal("expected error when neither DATABASE_URL nor DB_* vars are set, got nil")
	}
}

func TestLoad_InvalidAppEnv(t *testing.T) {
	clearEnv(t)
	t.Setenv("FRONTEND_URL", "http://localhost:3000")
	t.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db")
	t.Setenv("APP_ENV", "banana")

	if _, err := Load(); err == nil {
		t.Fatal("expected error for invalid APP_ENV, got nil")
	}
}

func TestLoad_InvalidPort(t *testing.T) {
	clearEnv(t)
	t.Setenv("FRONTEND_URL", "http://localhost:3000")
	t.Setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/db")
	t.Setenv("PORT", "not-a-number")

	if _, err := Load(); err == nil {
		t.Fatal("expected error for non-numeric PORT, got nil")
	}
}

func TestIsProduction(t *testing.T) {
	cfg := Config{AppEnv: "production"}
	if !cfg.IsProduction() {
		t.Error("expected IsProduction() to be true for APP_ENV=production")
	}
	cfg.AppEnv = "development"
	if cfg.IsProduction() {
		t.Error("expected IsProduction() to be false for APP_ENV=development")
	}
}
