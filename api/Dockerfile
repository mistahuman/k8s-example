FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN go build -o api-server main.go

FROM alpine:3.18
WORKDIR /app
COPY --from=builder /app/api-server /usr/local/bin/api-server
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/api-server"]
