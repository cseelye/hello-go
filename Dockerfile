FROM golang:1.13 as builder

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive  apt-get install --yes \
        upx-ucl

FROM scratch as release
COPY hello-go /hello-go
ENTRYPOINT ["/hello-go"]
