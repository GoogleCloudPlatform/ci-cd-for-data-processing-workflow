FROM golang:buster AS builder
COPY . /composer
WORKDIR /composer/cloudbuild/go/dagsdeployer/cmd/deploydags
ENV GO111MODULE=on
RUN CGO_ENABLED=0 GOOS=linux  go build -o /composer/deploydags .

FROM google/cloud-sdk:latest
COPY . /composer
COPY --from=builder /composer/deploydags /composer/deploydags
WORKDIR /composer
ENTRYPOINT ["/composer/deploydags"]
