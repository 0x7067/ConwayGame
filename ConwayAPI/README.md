# Conway's Game of Life REST API

[![ConwayAPI CI](https://github.com/0x7067/ConwayGame/actions/workflows/conwayapi-ci.yml/badge.svg)](https://github.com/0x7067/ConwayGame/actions/workflows/conwayapi-ci.yml)

A high-performance REST API for Conway's Game of Life simulation built with Swift and Vapor.

## Quick Start

### Prerequisites

- Swift 5.9 or later
- macOS 13+ or Linux

### Build and Run

```bash
swift build
swift run conway-api
```

The API will be available at `http://localhost:8080`

### Docker

```bash
docker build -t conway-api .
docker run -p 8080:8080 conway-api
```

Or use Docker Compose:

```bash
cd ConwayAPI
docker compose up
```

Notes:
- Compose builds with context at the repo root to include the local engine dependency (see Dockerfile).
- The runtime image includes `curl` for health checks.

### Docker Testing

Manual build and run (from repo root):

```bash
docker build -f ConwayAPI/Dockerfile -t conway-api:local .
docker run --rm -p 8080:8080 conway-api:local
```

Smoke tests:

```bash
curl -s localhost:8080/health | jq .
curl -s localhost:8080/api | jq .
curl -s localhost:8080/api/patterns | jq .
curl -s -X POST localhost:8080/api/game/step \
  -H 'Content-Type: application/json' \
  -d '{"grid":[[false,false,false,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,false,false,false]],"rules":"conway"}' | jq .
```

Helper script (build, run, health, smoke tests):

```bash
chmod +x ConwayAPI/scripts/verify_docker.sh
ConwayAPI/scripts/verify_docker.sh --port 8080
```

Options:
- `--port <host_port>`: Host port to bind (default: 8080)
- `--image <name>`: Image tag to build (default: conway-api:verify)
- `--platform <value>`: e.g., `linux/amd64` for cross-arch buildx
- `--compose`: Use `docker compose` instead of `docker run`

## API Documentation

### Health Check

**GET** `/health`

Returns API health status.

```json
{
  "status": "healthy",
  "timestamp": "2025-01-01T12:00:00Z",
  "version": "1.0.0"
}
```

### API Information

**GET** `/api`

Returns API metadata and available endpoints.

OpenAPI spec: see `ConwayAPI/openapi.yaml` (import into Swagger UI or Postman).

### Game Simulation

#### Compute Next Generation

**POST** `/api/game/step`

Computes the next generation for a given grid state.

**Request:**
```json
{
  "grid": [
    [false, true, false],
    [false, true, false],
    [false, true, false]
  ],
  "rules": "conway"
}
```

**Response:**
```json
{
  "grid": [
    [false, false, false],
    [true, true, true],
    [false, false, false]
  ],
  "generation": 1,
  "population": 3,
  "hasChanged": true
}
```

#### Run Full Simulation

**POST** `/api/game/simulate`

Runs a complete simulation for N generations.

**Request:**
```json
{
  "grid": [
    [false, true, false],
    [false, true, false],
    [false, true, false]
  ],
  "generations": 10,
  "rules": "conway",
  "includeHistory": true
}
```

#### Validate Grid

**POST** `/api/game/validate`

Validates grid format and returns validation results.

### Patterns

#### List All Patterns

**GET** `/api/patterns`

Returns all available predefined patterns.

#### Get Specific Pattern

**GET** `/api/patterns/{name}`

Returns a specific pattern with its grid data.

### Rules

#### List All Rule Configurations

**GET** `/api/rules`

Returns all available rule configurations.

### Monitoring

#### Performance Metrics

**GET** `/metrics`

Returns performance metrics in Prometheus-compatible format (if metrics are enabled).

**Response:**
```json
{
  "metrics": [
    {
      "name": "http_requests_total",
      "type": "counter",
      "value": 142,
      "tags": {"method": "POST", "endpoint": "/api/game/simulate"},
      "timestamp": "2025-01-01T12:00:00Z"
    },
    {
      "name": "http_request_duration_seconds",
      "type": "histogram", 
      "value": 0.023,
      "tags": {"method": "POST", "endpoint": "/api/game/simulate", "stat": "avg"},
      "timestamp": "2025-01-01T12:00:00Z"
    }
  ],
  "timestamp": "2025-01-01T12:00:00Z"
}

## Rule Systems

### Conway (Default)
- **Survival**: 2-3 neighbors
- **Birth**: 3 neighbors
- Classic Conway's Game of Life rules

### HighLife
- **Survival**: 2-3 neighbors  
- **Birth**: 3 or 6 neighbors
- Creates replicator patterns

### Day & Night
- **Survival**: 3-4, 6-8 neighbors
- **Birth**: 3, 6-8 neighbors
- Complex emergent behavior

## Available Patterns

| Pattern | Category | Description |
|---------|----------|-------------|
| `block` | Still Life | Simple 2x2 still life |
| `beehive` | Still Life | Stable hexagonal pattern |
| `blinker` | Oscillator | Period-2 oscillator |
| `toad` | Oscillator | Period-2 toad pattern |
| `beacon` | Oscillator | Period-2 beacon |
| `pulsar` | Oscillator | Period-3 pulsar |
| `glider` | Spaceship | Diagonal traveling pattern |
| `gospergun` | Gun | Glider-generating gun |

## Response Headers

All API responses include these headers for monitoring and debugging:

- `X-Correlation-ID`: Unique request identifier for tracing
- `X-Response-Time`: Response time in milliseconds
- `X-RateLimit-Limit`: Rate limit maximum for the endpoint (if rate limiting enabled)
- `X-RateLimit-Remaining`: Remaining requests in current window
- `X-RateLimit-Reset`: Unix timestamp when rate limit resets

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200` - Success
- `400` - Bad Request (invalid grid, parameters)
- `404` - Not Found (pattern not found)
- `429` - Too Many Requests (rate limit exceeded)
- `500` - Internal Server Error

Error responses include details:

```json
{
  "error": "ValidationError",
  "message": "Invalid grid: Row 1 has inconsistent width: expected 3, got 2",
  "timestamp": "2025-01-01T12:00:00Z"
}
```

Rate limit exceeded responses:

```json
{
  "error": "Rate limit exceeded",
  "message": "Too many requests. Try again later.",
  "retryAfter": 1672574400,
  "timestamp": "2025-01-01T12:00:00Z"
}
```

## Performance Considerations

- **Grid Size Limits**: No hard limits, but large grids may impact performance
- **Generation Limits**: Maximum 1000 generations per simulation request
- **Memory Usage**: Scales with grid size and history inclusion
- **Concurrency**: Fully async/await based for high throughput

## Configuration

The API supports extensive configuration via environment variables:

### Core Settings
- `PORT`: Port to listen on (default 8080)
- `ENVIRONMENT`: Vapor environment (`production`, `testing`, etc.)
- `API_VERSION`: API version string (default "1.0.0")

### Grid and Simulation Limits
- `MAX_GRID_WIDTH`: Maximum grid width allowed (default 200)
- `MAX_GRID_HEIGHT`: Maximum grid height allowed (default 200)
- `MAX_GENERATIONS`: Maximum generations per simulation (default 1000)

### CORS Configuration
- `CORS_ALLOWED_ORIGINS`: Comma-separated list of allowed origins (default "*")
  - Use `"*"` for development (allows all origins)
  - Use `"https://example.com,https://app.example.com"` for production
  - When specific origins are set, wildcard access is disabled for security

### Rate Limiting Configuration
- `ENABLE_RATE_LIMITING`: Enable rate limiting middleware (default true)
- `RATE_LIMIT_DEFAULT_MAX`: Default max requests per window (default 100)
- `RATE_LIMIT_DEFAULT_WINDOW`: Default time window in seconds (default 60)
- `RATE_LIMIT_SIMULATE_MAX`: Max requests for /api/game/simulate (default 20)
- `RATE_LIMIT_SIMULATE_WINDOW`: Time window for simulate endpoint (default 60)
- `RATE_LIMIT_GAME_MAX`: Max requests for game endpoints (default 50)
- `RATE_LIMIT_HEALTH_MAX`: Max requests for health endpoint (default 300)

### Monitoring and Metrics
- `ENABLE_METRICS`: Enable performance metrics collection (default true)
- `ENABLE_REQUEST_LOGGING`: Enable detailed request logging (default true)

### Example Production Configuration

```bash
export MAX_GRID_WIDTH=100
export MAX_GRID_HEIGHT=100
export MAX_GENERATIONS=500
export CORS_ALLOWED_ORIGINS="https://myapp.com,https://www.myapp.com"
export API_VERSION="1.0.0"
export ENVIRONMENT=production

# Rate limiting for production
export RATE_LIMIT_SIMULATE_MAX=10
export RATE_LIMIT_GAME_MAX=30
export RATE_LIMIT_DEFAULT_MAX=60

# Monitoring
export ENABLE_METRICS=true
export ENABLE_REQUEST_LOGGING=false  # Reduce log volume in production
```

### Security Notes
- Production deployments should set specific CORS origins instead of "*"
- Rate limiting protects against abuse and resource exhaustion
- All requests include `X-Correlation-ID` headers for debugging and tracing
- Performance metrics are available at `/metrics` endpoint (if enabled)
- JSON dates use ISO 8601 format for consistency

## Limits & Behavior

- Generations: `/api/game/simulate` is capped at configurable max (default 1000 generations)
- Grid shape: grids must be rectangular and non-empty; validation returns `width`, `height`, and errors
- Grid size caps: requests exceeding configured limits (default 200x200) are rejected with a clear error to protect resources
- Rule presets: `conway`, `highlife`, `daynight` (alias `day-night`, `dayandnight`)
- Rate limiting: different limits for compute-intensive vs read-only endpoints
- All responses include performance and debugging headers (`X-Correlation-ID`, `X-Response-Time`, rate limit headers)

## Toolchains

- Developed and tested with Swift 5.9+.
- CI runs on Swift 5.10 and 6.0 (Linux + macOS).

## Development

### Testing

```bash
swift test
```

### Building for Release

```bash
swift build -c release
```

<!-- Environment variables are documented above in Configuration -->

## Architecture

The API leverages the ConwayGameEngine Swift package:

- **Game Logic**: Pure Swift implementation with configurable rules
- **Performance**: Optimized neighbor counting and early termination
- **Validation**: Comprehensive grid validation and error handling
- **Patterns**: Predefined pattern library with multiple categories
- **Convergence**: Automatic detection of extinction and cycles

## License

This project is part of the Conway Game of Life implementation.
