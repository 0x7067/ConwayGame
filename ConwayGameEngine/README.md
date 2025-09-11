# ConwayGameEngine

[![ConwayAPI CI](https://github.com/0x7067/ConwayGame/actions/workflows/conwayapi-ci.yml/badge.svg)](https://github.com/0x7067/ConwayGame/actions/workflows/conwayapi-ci.yml)

Core Swift package implementing Conway's Game of Life. Provides:
- `ConwayGameEngine` library with configurable rules and pattern library
- `conway-cli` executable for terminal simulations
- Unit tests for engine components

## Build & Test

```bash
cd ConwayGameEngine
swift test
swift build --product conway-cli
```

## Run CLI

```bash
cd ConwayGameEngine
swift run conway-cli --help
swift run conway-cli run 20 20 50 random --rules=conway
swift run conway-cli pattern glider --rules=daynight
```

## Rules

Built-in presets:
- `conway` (B3/S23)
- `highlife` (B36/S23)
- `daynight` (B3678/S34678)

## Notes

- The engine uses identity short-circuiting (returns the same grid instance when the generation is unchanged).
- Convergence detector identifies extinction and repeats; period reporting is generic (period=0) without full history indexing.
- See `ConwayAPI` for the REST interface to this engine.
