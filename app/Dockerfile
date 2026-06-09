# Builder
FROM golang:1.25-alpine AS builder

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

# Reszta kodu źródłowego
COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /build .

# Runtime
FROM alpine:3.20

RUN apk add --no-cache ca-certificates

RUN adduser -D -u 10001 appuser
USER appuser

WORKDIR /app
COPY --from=builder /build .

ENV PORT=8000
EXPOSE 8000

ENTRYPOINT ["/app/build"]
