# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Conway's Game of Life implementation with three components:
- **ConwayGame/** - iOS SwiftUI app with Core Data persistence
- **ConwayGameEngine/** - Reusable Swift Package with pure game logic and CLI
- **ConwayAPI/** - Vapor REST API exposing engine functionality

## Build & Test Commands

```bash
# iOS app tests (all)
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# iOS specific test class
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests

# iOS specific test method
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests/testBasicPatterns

# Engine package tests
cd ConwayGameEngine && swift test

# API tests
cd ConwayAPI && swift test

# Run CLI
cd ConwayGameEngine && swift run conway-cli pattern glider
cd ConwayGameEngine && swift run conway-cli run 10 10 20 random --density=0.3 --rules=highlife

# Run API server
cd ConwayAPI && swift run conway-api

# Format code (run before committing)
swiftformat ConwayGameEngine ConwayAPI

# Check formatting
swiftformat ConwayGameEngine ConwayAPI --lint
```

## Architecture

```
┌─────────────────────────┐
│  iOS App (SwiftUI)      │  Views → ViewModels
├─────────────────────────┤
│  Service Layer          │  GameService
├─────────────────────────┤
│  Repository Layer       │  CoreDataBoardRepository
├─────────────────────────┤
│  ConwayGameEngine       │  Pure game logic, no dependencies
└─────────────────────────┘
```

**Key patterns:**
- Protocol-oriented design for all major components (testability)
- MVVM with `@MainActor` ViewModels
- Repository pattern abstracting Core Data
- Dependency injection via FactoryKit (`FactoryContainer.swift`)
- Centralized configuration (`GameEngineConfiguration`) eliminates magic numbers

**Naming conventions:**
- Protocols describe behavior: `GameEngine`, `GameService`, `BoardRepository`
- Implementations prefixed: `ConwayGameEngine`, `DefaultGameService`, `CoreDataBoardRepository`

## Code Style

SwiftFormat enforced in CI:
- Swift 5.9+, compatible with Swift 6 language mode
- 4-space indentation, 120-char line length
- No redundant `self`, alphabetized imports
- Use `struct` over `class` when possible
- Use `@inline(__always)` only for proven hot paths

## Error Handling

- `GameError` enum for core operations
- `UserFriendlyError` protocol for UI-facing errors with recovery actions
- Context-aware wrapping via `ConwayGameUserError`

## Testing

- >90% coverage target for core logic
- Integration tests in `EndToEndWorkflowTests.swift`, `CoreDataIntegrationTests.swift`
- `SyntheticDataGenerator.swift` for large dataset testing
- API tests use `XCTVapor` async helpers
