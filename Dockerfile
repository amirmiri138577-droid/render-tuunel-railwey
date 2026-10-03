# Build Rathole natively for the Alpine-based PasarGuard Node image.
ARG RATHOLE_VERSION=v0.5.0
ARG PASARGUARD_NODE_IMAGE=pasarguard/node:v0.5.4

FROM rust:1.79-alpine AS rathole-build
ARG RATHOLE_VERSION
RUN apk add --no-cache musl-dev build-base curl tar gzip \
    && mkdir -p /src \
    && curl -fsSL "https://github.com/rathole-org/rathole/archive/refs/tags/${RATHOLE_VERSION}.tar.gz" \
       | tar -xz -C /src \
    && cd "/src/rathole-${RATHOLE_VERSION#v}" \
    && cargo build --release --locked --no-default-features --features server,client \
    && install -m 0755 target/release/rathole /rathole

FROM ${PASARGUARD_NODE_IMAGE}
USER root
# Render Web Services need a real HTTP listener on the injected PORT.
# Install BusyBox explicitly instead of relying on the base image contents.
RUN apk add --no-cache openssl busybox

COPY --from=rathole-build /rathole /usr/local/bin/rathole
COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh /usr/local/bin/rathole

ENV NODE_HOST=0.0.0.0 \
    SSL_CERT_FILE=/var/lib/pg-node/certs/ssl_cert.pem \
    SSL_KEY_FILE=/var/lib/pg-node/certs/ssl_key.pem \
    GENERATED_CONFIG_PATH=/var/lib/pg-node/generated \
    SERVICE_PROTOCOL=grpc

ENTRYPOINT ["/entrypoint.sh"]
