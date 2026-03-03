# syntax=docker/dockerfile:1
# Mayam — Multi-Architecture Docker Image
# Supports linux/amd64 and linux/arm64
#
# Build:
#   docker buildx build --platform linux/amd64,linux/arm64 -t mayam:latest .
#
# Run:
#   docker run -p 11112:11112 -p 8080:8080 -p 8081:8081 mayam:latest
#
# Reference: Milestone 13 — Docker / OCI container images

# ============================================================
# Stage 1: Build
# ============================================================
FROM --platform=$BUILDPLATFORM swift:6.0-jammy AS builder

WORKDIR /build

# Copy package manifest first for dependency caching
COPY Package.swift ./
RUN swift package resolve

# Copy source code
COPY Sources/ Sources/
COPY Tests/ Tests/
COPY Config/ Config/

# Build release binary
RUN swift build -c release --static-swift-stdlib \
    -Xlinker -lstdc++ \
    && mv .build/release/mayam /build/mayam

# ============================================================
# Stage 2: Runtime
# ============================================================
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libicu70 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r mayam && useradd -r -g mayam -d /var/lib/mayam -s /bin/false mayam

# Create directories
RUN mkdir -p /var/lib/mayam/archive /etc/mayam /var/log/mayam \
    && chown -R mayam:mayam /var/lib/mayam /var/log/mayam

# Copy binary and default configuration
COPY --from=builder /build/mayam /usr/local/bin/mayam
COPY Config/mayam.yaml /etc/mayam/mayam.yaml

# Environment variable defaults
ENV MAYAM_CONFIG=/etc/mayam/mayam.yaml \
    MAYAM_STORAGE_ARCHIVE_PATH=/var/lib/mayam/archive \
    MAYAM_LOG_LEVEL=info

# Expose ports
# 11112 - DICOM associations
# 8080  - DICOMweb HTTP
# 8081  - Admin console
EXPOSE 11112 8080 8081

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run as non-root user
USER mayam

ENTRYPOINT ["mayam"]
