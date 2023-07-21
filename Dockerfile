# Compiling stage
FROM golang:1.16-alpine AS builder

WORKDIR /app

COPY . .

RUN go build -o main

# Production stage
FROM alpine:latest

WORKDIR /app

COPY --from=builder /app/main .

EXPOSE 8080

CMD ["./main"]
