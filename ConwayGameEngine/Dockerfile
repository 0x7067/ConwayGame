# Multi-stage build for Conway Game of Life API

# Build stage
FROM swift:5.9-jammy as build

# Install system dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
        libc6-dev \
        libcurl4-openssl-dev \
        libedit-dev \
        libgcc-9-dev \
        libpython3.8 \
        libsqlite3-dev \
        libstdc++-9-dev \
        libxml2-dev \
        libz3-dev \
        pkg-config \
        tzdata \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy package files
COPY Package.swift .
COPY Package.resolved .

# Copy source code
COPY Sources/ Sources/
COPY Tests/ Tests/

# Build the application in release mode
RUN swift build -c release --static-swift-stdlib

# Runtime stage
FROM ubuntu:jammy-20240530

# Install runtime dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q install -y \
        ca-certificates \
        tzdata \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Create a user for the app
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app conway

# Copy the built application
COPY --from=build --chown=conway:conway /app/.build/release/conway-api /app/conway-api

# Set working directory and user
WORKDIR /app
USER conway:conway

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["./conway-api"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]