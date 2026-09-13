# ---- build stage ----
FROM golang:1.25-alpine AS builder

WORKDIR /src

# Cache dependency downloads separately from source changes.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# ---- runtime stage ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates && \
    adduser -D -H -u 10001 appuser

WORKDIR /app
COPY --from=builder /out/api ./api

USER appuser

EXPOSE 8080

ENTRYPOINT ["./api"]
