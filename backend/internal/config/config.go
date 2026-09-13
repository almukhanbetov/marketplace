// Package config loads and validates application configuration from
// environment variables. Nothing in this package talks to the network or
// the database — it only produces a validated, ready-to-use Config value.
package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all runtime configuration for the API server.
type Config struct {
	AppEnv string
	Port   string

	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string

	// DatabaseURL, when set, takes precedence over the individual DB_* vars.
	// This is the primary way production deployments configure the database.
	DatabaseURL string

	FrontendURL string

	// DBConnectTimeout bounds how long we wait for the initial pool
	// connection + ping at startup.
	DBConnectTimeout time.Duration

	// Stage 9 authentication. JWTAccessSecret signs access tokens — there
	// is no safe default; Load fails closed if it's missing or too short
	// (Stage 9 §33/§34: never ship a real secret in the repo, and never
	// silently fall back to a weak one either).
	JWTAccessSecret string
	JWTAccessTTL    time.Duration
	RefreshTokenTTL time.Duration

	// CookieSecure controls the refresh cookie's Secure attribute — true
	// in any real deployment (HTTPS only), false only for plain-HTTP
	// localhost dev (Stage 9 §32).
	CookieSecure bool
	// CookieDomain is left empty by default (host-only cookie, scoped to
	// whatever host issued it) — only set it in production if the API and
	// frontend share a registrable domain across subdomains.
	CookieDomain string
}

const (
	defaultPort             = "8080"
	defaultDBSSLMode        = "disable"
	defaultDBConnectTimeout = 5 * time.Second
	defaultJWTAccessTTL     = 15 * time.Minute
	defaultRefreshTokenTTL  = 30 * 24 * time.Hour
	minJWTSecretLength      = 32
)

// Load reads configuration from the process environment and validates it.
// It never reads a .env file itself — that is the responsibility of the
// process supervisor (docker compose, a shell export, etc.) so the same
// binary behaves identically in every environment.
func Load() (Config, error) {
	cfg := Config{
		AppEnv: getEnv("APP_ENV", "development"),
		Port:   getEnv("PORT", defaultPort),

		DBHost:     os.Getenv("DB_HOST"),
		DBPort:     os.Getenv("DB_PORT"),
		DBName:     os.Getenv("DB_NAME"),
		DBUser:     os.Getenv("DB_USER"),
		DBPassword: os.Getenv("DB_PASSWORD"),
		DBSSLMode:  getEnv("DB_SSLMODE", defaultDBSSLMode),

		DatabaseURL: os.Getenv("DATABASE_URL"),

		FrontendURL: os.Getenv("FRONTEND_URL"),

		DBConnectTimeout: defaultDBConnectTimeout,

		JWTAccessSecret: os.Getenv("JWT_ACCESS_SECRET"),
		JWTAccessTTL:    defaultJWTAccessTTL,
		RefreshTokenTTL: defaultRefreshTokenTTL,
		CookieSecure:    getEnv("COOKIE_SECURE", "false") == "true",
		CookieDomain:    os.Getenv("COOKIE_DOMAIN"),
	}

	if v := os.Getenv("JWT_ACCESS_TTL_MINUTES"); v != "" {
		if minutes, err := strconv.Atoi(v); err == nil && minutes > 0 {
			cfg.JWTAccessTTL = time.Duration(minutes) * time.Minute
		}
	}
	if v := os.Getenv("REFRESH_TOKEN_TTL_DAYS"); v != "" {
		if days, err := strconv.Atoi(v); err == nil && days > 0 {
			cfg.RefreshTokenTTL = time.Duration(days) * 24 * time.Hour
		}
	}

	if err := cfg.validate(); err != nil {
		return Config{}, err
	}

	return cfg, nil
}

func (c Config) validate() error {
	var errs []string

	if _, err := strconv.Atoi(c.Port); err != nil || c.Port == "" {
		errs = append(errs, "PORT must be a non-empty numeric string")
	}

	if c.FrontendURL == "" {
		errs = append(errs, "FRONTEND_URL is required")
	}

	// Either a full DATABASE_URL or the complete set of DB_* parts must be
	// present — we need enough information to build a connection string.
	if c.DatabaseURL == "" {
		missing := []string{}
		if c.DBHost == "" {
			missing = append(missing, "DB_HOST")
		}
		if c.DBPort == "" {
			missing = append(missing, "DB_PORT")
		}
		if c.DBName == "" {
			missing = append(missing, "DB_NAME")
		}
		if c.DBUser == "" {
			missing = append(missing, "DB_USER")
		}
		// DB_PASSWORD may legitimately be empty in some local trust-auth
		// setups, so it is not treated as required.
		if len(missing) > 0 {
			errs = append(errs, fmt.Sprintf(
				"DATABASE_URL is not set, and the following DB_* variables are missing: %s",
				strings.Join(missing, ", "),
			))
		}
	}

	switch c.AppEnv {
	case "development", "staging", "production", "test":
	default:
		errs = append(errs, "APP_ENV must be one of: development, staging, production, test")
	}

	if len(c.JWTAccessSecret) < minJWTSecretLength {
		errs = append(errs, fmt.Sprintf("JWT_ACCESS_SECRET is required and must be at least %d characters", minJWTSecretLength))
	}
	if c.IsProduction() && !c.CookieSecure {
		errs = append(errs, "COOKIE_SECURE must be true when APP_ENV=production")
	}

	if len(errs) > 0 {
		return errors.New("invalid configuration: " + strings.Join(errs, "; "))
	}

	return nil
}

// ConnString returns the PostgreSQL connection string to use, preferring
// DATABASE_URL when present and otherwise assembling one from the DB_*
// parts.
func (c Config) ConnString() string {
	if c.DatabaseURL != "" {
		return c.DatabaseURL
	}

	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName, c.DBSSLMode,
	)
}

// IsProduction reports whether the app is running with APP_ENV=production.
func (c Config) IsProduction() bool {
	return c.AppEnv == "production"
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
