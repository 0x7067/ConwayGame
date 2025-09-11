# Build stage
FROM swift:5.9-jammy AS build

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app/ConwayAPI

# Copy ConwayAPI package manifests
COPY ConwayAPI/Package.swift ./
COPY ConwayAPI/Package.resolved ./

# Copy dependency package (local path dependency)
COPY ConwayGameEngine /app/ConwayGameEngine

# Copy source code
COPY ConwayAPI/Sources ./Sources
COPY ConwayAPI/Tests ./Tests

# Build the application
RUN swift build -c release --static-swift-stdlib

# Production stage
FROM ubuntu:jammy-20240808

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app conway

# Set work directory and user
WORKDIR /app
USER conway:conway

# Copy built executable
COPY --from=build --chown=conway:conway /app/ConwayAPI/.build/release/conway-api /app/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Set entrypoint
ENTRYPOINT ["./conway-api"]
