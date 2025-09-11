# Conway's Game of Life

A Swift implementation of Conway's Game of Life with:
- An iOS app (SwiftUI) under `ConwayGame`
- A reusable engine as a Swift Package under `ConwayGameEngine`
- A CLI executable target `conway-cli` for terminal simulations

## Quick Start (App)
- Requirements: Xcode 15+, iOS 16+ simulator/device, macOS 13+
- Open the project: `open ConwayGame.xcodeproj`
- Select the `ConwayGame` scheme and run on a simulator or device.

## CLI Usage
The CLI lives in the Swift package at `ConwayGameEngine`.

- Build and run from the package directory:
  - `cd ConwayGameEngine`
  - `swift run conway-cli --help`

- Commands:
  - `conway-cli run <width> <height> <generations> [pattern] [--density=<value>] [--rules=<name>]`
    - Runs a simulation with the given grid size and generation count
    - Optional `pattern`: `random`, `empty`, or a named pattern
    - `--density`: Random density (0.0-1.0), default: 0.25
    - `--rules`: Rule preset (conway, highlife, daynight), default: conway
  - `conway-cli pattern <name> [--rules=<name>]`
    - Runs a predefined pattern for a short showcase
    - `--rules`: Rule preset (conway, highlife, daynight), default: conway

- Examples:
  - `swift run conway-cli run 20 20 50 random`
  - `swift run conway-cli run 10 10 25 empty --density=0.4`
  - `swift run conway-cli run 15 15 30 random --rules=highlife`
  - `swift run conway-cli pattern glider --rules=daynight`

Available patterns: `block`, `beehive`, `blinker`, `toad`, `beacon`, `glider`, `pulsar`, `gospergun`.

Output uses `*` for alive and `.` for dead.

## Rules & Variants
The engine supports multiple configurable rule sets:

### Conway's Game of Life (Default)
- Neighborhood: Moore (8 surrounding cells)
- Survival: a live cell with 2 or 3 neighbors stays alive
- Birth: a dead cell with exactly 3 neighbors becomes alive
- Otherwise: the cell is dead in the next generation

### Additional Rule Variants
- **HighLife**: Conway rules + birth on 6 neighbors
- **Day and Night**: Survival on 3,4,6,7,8 neighbors; birth on 3,6,7,8 neighbors

Use `--rules=<name>` in CLI or configure programmatically in the iOS app.

## Finish Criteria & Limits
- Finished states (engine/app/CLI):
  - Extinction: all cells are dead.
  - Cycle detected: a previously seen board state recurs (includes still lifes with period 1 and oscillators with period > 1).
- iOS app limits:
  - Auto-play cap: pauses after 500 steps per run.
  - Final state search cap: attempts up to 500 generations; if living cells remain with no cycle/extinction, it reports that the generation limit was reached.
- CLI behavior:
  - `run`: runs exactly the number of generations requested, but stops early on extinction or when a repeated state is detected.
  - `pattern`: showcases up to configurable generations (default: 50) with short delays; also stops early if the pattern stabilizes.

## Assumptions
- Bounded grid: no wrap-around at edges (cells outside the grid are always dead).
- Synchronous updates: the next generation is computed from the entire current state.
- CLI `random` starts with configurable density (default: 25% alive cells).
- Sim termination hints in CLI: stops on extinction or when a previously seen state recurs (cycle detected).

## Development
- Engine tests: `cd ConwayGameEngine && swift test`
- Build CLI only: `cd ConwayGameEngine && swift build`
- Run CLI: `cd ConwayGameEngine && swift run conway-cli ...`

Engine entry points:
- `ConwayGameEngine.computeNextState(_:)` — next generation.
- `ConwayGameEngine.computeStateAtGeneration(_:generation:)` — advance multiple generations.

---
If you want, I can add a `Makefile` with common tasks or expand the README with screenshots and advanced usage.
