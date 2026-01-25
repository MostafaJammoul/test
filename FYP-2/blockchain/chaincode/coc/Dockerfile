FROM golang:1.21-alpine AS builder

WORKDIR /chaincode

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY *.go ./

# Build chaincode
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o chaincode .

# Final image
FROM alpine:3.18

RUN apk add --no-cache ca-certificates

WORKDIR /chaincode

COPY --from=builder /chaincode/chaincode .

# Set chaincode environment variables (to be overridden at runtime)
ENV CHAINCODE_SERVER_ADDRESS=0.0.0.0:9999
ENV CHAINCODE_ID=""

EXPOSE 9999

CMD ["./chaincode"]
