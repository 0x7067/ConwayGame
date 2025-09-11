# Conway's Game of Life REST API

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
docker-compose up
```

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

## Error Handling

All endpoints return appropriate HTTP status codes:

- `200` - Success
- `400` - Bad Request (invalid grid, parameters)
- `404` - Not Found (pattern not found)
- `500` - Internal Server Error

Error responses include details:

```json
{
  "error": "ValidationError",
  "message": "Invalid grid: Row 1 has inconsistent width: expected 3, got 2",
  "timestamp": "2025-01-01T12:00:00Z"
}
```

## Performance Considerations

- **Grid Size Limits**: No hard limits, but large grids may impact performance
- **Generation Limits**: Maximum 1000 generations per simulation request
- **Memory Usage**: Scales with grid size and history inclusion
- **Concurrency**: Fully async/await based for high throughput

## Development

### Testing

```bash
swift test
```

### Building for Release

```bash
swift build -c release
```

### Environment Variables

- `PORT`: Server port (default: 8080)
- `ENVIRONMENT`: Environment (development/production)

## Architecture

The API leverages the ConwayGameEngine Swift package:

- **Game Logic**: Pure Swift implementation with configurable rules
- **Performance**: Optimized neighbor counting and early termination
- **Validation**: Comprehensive grid validation and error handling
- **Patterns**: Predefined pattern library with multiple categories
- **Convergence**: Automatic detection of extinction and cycles

## License

This project is part of the Conway Game of Life implementation.