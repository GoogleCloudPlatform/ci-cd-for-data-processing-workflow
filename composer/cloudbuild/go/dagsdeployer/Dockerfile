FROM golang:buster AS builder
COPY . /dagsdeployer
WORKDIR /dagsdeployer/cmd/deploydags
ENV GO111MODULE=on
RUN CGO_ENABLED=0 GOOS=linux  go build -o /app/deploydags .

FROM google/cloud-sdk:latest
COPY --from=builder /app/deploydags /app/deploydags
WORKDIR /app
ENTRYPOINT ["/app/deploydags"]
