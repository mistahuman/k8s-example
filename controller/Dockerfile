FROM golang:1.21 AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /controller main.go

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /controller /controller
USER nonroot:nonroot
ENTRYPOINT ["/controller"]
