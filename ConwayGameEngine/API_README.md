# Conway's Game of Life REST API

A high-performance REST API for Conway's Game of Life simulation built with Swift and Vapor.

## Quick Start

### Build and Run

```bash
cd ConwayGameEngine
swift build
swift run conway-api
```

The API will be available at `http://localhost:8080`

### Docker

```bash
docker build -t conway-api .
docker run -p 8080:8080 conway-api
```

## API Endpoints

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

**Response:**
```json
{
  "initialGrid": [
    [false, true, false],
    [false, true, false],
    [false, true, false]
  ],
  "finalGrid": [
    [false, false, false],
    [true, true, true],
    [false, false, false]
  ],
  "generationsRun": 2,
  "finalPopulation": 3,
  "convergence": {
    "type": "cyclical",
    "period": 2,
    "finalGeneration": 2
  },
  "history": [
    {
      "generation": 0,
      "grid": [[false, true, false], [false, true, false], [false, true, false]],
      "population": 3
    }
  ]
}
```

#### Validate Grid

**POST** `/api/game/validate`

Validates grid format and returns validation results.

**Request:**
```json
{
  "grid": [
    [false, true, false],
    [false, true, false],
    [false, true, false]
  ]
}
```

**Response:**
```json
{
  "isValid": true,
  "width": 3,
  "height": 3,
  "population": 3,
  "errors": []
}
```

### Patterns

#### List All Patterns

**GET** `/api/patterns`

Returns all available predefined patterns.

**Response:**
```json
{
  "patterns": [
    {
      "name": "glider",
      "displayName": "Glider",
      "description": "The smallest spaceship that travels diagonally.",
      "category": "Spaceship",
      "width": 7,
      "height": 7
    }
  ]
}
```

#### Get Specific Pattern

**GET** `/api/patterns/{name}`

Returns a specific pattern with its grid data.

**Response:**
```json
{
  "name": "glider",
  "displayName": "Glider",
  "description": "The smallest spaceship that travels diagonally.",
  "category": "Spaceship",
  "grid": [
    [false, false, true, false, false, false, false],
    [false, false, false, true, false, false, false],
    [false, true, true, true, false, false, false],
    [false, false, false, false, false, false, false],
    [false, false, false, false, false, false, false],
    [false, false, false, false, false, false, false],
    [false, false, false, false, false, false, false]
  ],
  "width": 7,
  "height": 7
}
```

### Rules

#### List All Rule Configurations

**GET** `/api/rules`

Returns all available rule configurations.

**Response:**
```json
{
  "rules": [
    {
      "name": "conway",
      "displayName": "Conway's Game of Life",
      "description": "The classic Conway's Game of Life rules: B3/S23",
      "survivalNeighborCounts": [2, 3],
      "birthNeighborCounts": [3]
    },
    {
      "name": "highlife",
      "displayName": "HighLife",
      "description": "HighLife variant: B36/S23 - births on 3 or 6 neighbors",
      "survivalNeighborCounts": [2, 3],
      "birthNeighborCounts": [3, 6]
    },
    {
      "name": "daynight",
      "displayName": "Day & Night",
      "description": "Day & Night rules: B3678/S34678 - complex behavior",
      "survivalNeighborCounts": [3, 4, 6, 7, 8],
      "birthNeighborCounts": [3, 6, 7, 8]
    }
  ]
}
```

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

## Examples

### Simple Blinker Pattern

```bash
curl -X POST http://localhost:8080/api/game/step \
  -H "Content-Type: application/json" \
  -d '{
    "grid": [
      [false, false, false, false, false],
      [false, false, true, false, false],
      [false, false, true, false, false],
      [false, false, true, false, false],
      [false, false, false, false, false]
    ],
    "rules": "conway"
  }'
```

### Get Glider Pattern

```bash
curl http://localhost:8080/api/patterns/glider
```

### Run Simulation with History

```bash
curl -X POST http://localhost:8080/api/game/simulate \
  -H "Content-Type: application/json" \
  -d '{
    "grid": [
      [false, true, false],
      [false, false, true],
      [true, true, true]
    ],
    "generations": 4,
    "rules": "conway",
    "includeHistory": true
  }'
```

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Running

```bash
swift run conway-api
```

The API will start on port 8080 by default. Use environment variables to configure:

- `PORT`: Server port (default: 8080)
- `ENVIRONMENT`: Environment (development/production)

## Architecture

The API leverages the existing ConwayGameEngine Swift package:

- **Game Logic**: Pure Swift implementation with configurable rules
- **Performance**: Optimized neighbor counting and early termination
- **Validation**: Comprehensive grid validation and error handling
- **Patterns**: Predefined pattern library with multiple categories
- **Convergence**: Automatic detection of extinction and cycles