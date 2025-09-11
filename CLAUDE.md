# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ConwayGame is a production-ready iOS implementation of Conway's Game of Life built with SwiftUI and Core Data. The architecture follows clean separation of concerns with distinct layers for game logic, persistence, and UI.

## Documentation Structure

This project maintains several documentation files with distinct purposes:

- **CLAUDE.md** (this file): Guidance for Claude Code AI assistant when working with the codebase
- **CONTRIBUTING.md**: Comprehensive contributor guide for human developers (setup, architecture, workflow)
- **README.md**: Project overview and quick start instructions for end users
- **GitHub Templates** (`.github/`): Structured templates for issues and pull requests
  - Bug reports, feature requests, performance issues, documentation, and questions
  - Pull request template with architecture impact assessment and testing checklists

## Build and Test Commands

```bash
# Build the project
xcodebuild -scheme ConwayGame -configuration Debug build

# Run all tests
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run specific test target
xcodebuild -scheme ConwayGameTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Run specific test file (example)
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests

# Run specific test method (example)
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests/testBasicPatterns

# Build for release
xcodebuild -scheme ConwayGame -configuration Release build

# Clean build folder
xcodebuild -scheme ConwayGame clean

# Swift Package commands
cd ConwayGameEngine

# Build Swift Package
swift build

# Run Swift Package tests
swift test

# Run CLI tool
swift run conway-cli --help
swift run conway-cli pattern glider
```

## Architecture Overview

The codebase follows a layered architecture designed for future extensibility and platform independence:

### Core Layers

1. **Pure Game Logic Layer** (`Services/GameEngine.swift`)
   - `GameEngine` protocol: Core Conway's Game of Life computation
   - `ConwayGameEngine`: Optimized implementation with early termination for stable states
   - `GameRules`: Static methods for cell survival/birth logic and neighbor counting

2. **Data Layer** (`Models/`)
   - `Board`: Main entity with validation, state history for convergence detection
   - `GameState`: Represents computed state at specific generation
   - `GameError`: Comprehensive error handling enumeration
   - `ConvergenceType`: Tracks game state evolution (continuing/extinct/cyclical)

3. **Service Layer** (`Services/GameService.swift`)
   - `GameService` protocol: Business logic orchestration
   - `DefaultGameService`: Coordinates game engine, persistence, and convergence detection
   - Async/await patterns for all operations

4. **Repository Pattern** (`Repository/`)
   - `BoardRepository` protocol: Persistence abstraction
   - `CoreDataBoardRepository`: Core Data implementation
   - Complete CRUD operations for boards

5. **Dependency Injection** (`Utils/ServiceContainer.swift`)
   - Singleton container managing all service dependencies
   - Ensures consistent object graph throughout app

### Key Design Patterns

- **Protocol-oriented design**: All major components are protocol-based for testability
- **Repository pattern**: Abstracts persistence layer
- **MVVM**: ViewModels coordinate between UI and services
- **Convergence detection**: Uses state hashing and history tracking for cycle/stability detection

## Testing Structure

- `GameEngineTests.swift`: Core Conway's Game logic, edge cases, patterns
- `GameServiceTests.swift`: Service layer integration tests
- `ConvergenceDetectorTests.swift`: Convergence detection algorithms
- `BoardRepositoryTests.swift`: Persistence layer tests
- `ViewModelTests.swift`: UI logic tests

## Performance Considerations

- **Memory optimization**: Uses `@inline(__always)` for hot paths in game logic
- **Identity checking**: Game engine returns same instance when no changes occur
- **Early termination**: Computation stops when stable states are detected
- **Background processing**: Long computations run on background queues
- **State hashing**: Efficient bit-packed base64 encoding for cycle detection

## Core Data Integration

- Uses `PersistenceController.shared` for Core Data stack
- Boards persist across app launches with full state history
- Environment injection via `.managedObjectContext` in SwiftUI

## Key Files for Extension

- `GameEngine.swift`: Modify game rules or add new algorithms
- `GameService.swift`: Add new game operations or API endpoints
- `Board.swift`: Extend data model (ensure validation updates)
- `ServiceContainer.swift`: Register new dependencies
- `ConvergenceDetector.swift`: Enhance convergence detection algorithms

### Documentation Files
- `CONTRIBUTING.md`: Update when architecture changes or new development processes are added
- `.github/ISSUE_TEMPLATE/`: Update templates when new components are added or issue categories change
- `.github/pull_request_template.md`: Update when new architecture layers or testing requirements are introduced

## Development Notes

- Game logic is completely UI-independent for future platform portability
- All async operations use structured concurrency
- Comprehensive error handling with typed errors
- State validation occurs at model level with throwing initializers
- Logging uses OSLog framework with categorized loggers

### Documentation Maintenance

When making changes to the codebase, consider updating documentation:

- **Architecture changes**: Update both CLAUDE.md and CONTRIBUTING.md to reflect new layers, patterns, or components
- **New features**: Update GitHub issue templates if new feature categories are introduced
- **Testing changes**: Update pull request template checklist and CONTRIBUTING.md testing sections
- **Build process changes**: Update build commands in both CLAUDE.md and CONTRIBUTING.md
- **New dependencies**: Update setup instructions in CONTRIBUTING.md

Refer contributors to CONTRIBUTING.md for comprehensive setup and development workflow guidance.