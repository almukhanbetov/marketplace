# ---- build stage ----
FROM golang:1.25-alpine AS builder

WORKDIR /src

# Cache dependency downloads separately from source changes.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate

# ---- shared runtime base ----
FROM alpine:3.20 AS runtime-base

RUN apk add --no-cache ca-certificates && \
    adduser -D -H -u 10001 appuser

WORKDIR /app

# ---- migrate target: forward Goose migrations only ----
# Deployment must only ever run this image/target with the default "up"
# command (or invoke it explicitly as "up") — never "reset", "down",
# "down-to", or "redo" against production data.
FROM runtime-base AS migrate

COPY --from=builder /out/migrate ./migrate
COPY --from=builder /src/migrations ./migrations

USER appuser

ENTRYPOINT ["./migrate"]
CMD ["up"]

# ---- api target: the production API server (default build target, kept
# last so `docker build .` with no --target preserves today's behavior) ----
FROM runtime-base AS api

COPY --from=builder /out/api ./api

USER appuser

EXPOSE 8080

ENTRYPOINT ["./api"]
