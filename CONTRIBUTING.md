# Contributing to Conway's Game of Life

Welcome! This project implements Conway's Game of Life as a production-ready iOS app with a reusable Swift Package engine. We appreciate your interest in contributing.

## Quick Start

### Prerequisites
- **Xcode 15+** with iOS 16+ simulator support
- **macOS 13+**
- **Git** for version control

### Local Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ConwayGame-dependencyInjection
   ```

2. **Open the iOS project**
   ```bash
   open ConwayGame.xcodeproj
   ```

3. **Verify setup by running tests**
   ```bash
   # iOS app tests
   xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
   
   # Swift Package tests
   cd ConwayGameEngine && swift test
   ```

4. **Run the app**
   - Select the `ConwayGame` scheme in Xcode
   - Choose an iOS simulator or device
   - Build and run (⌘+R)

5. **Try the CLI (optional)**
   ```bash
   cd ConwayGameEngine
   swift run conway-cli pattern glider
   swift run conway-cli run 10 10 20 random --density=0.3 --rules=highlife
   ```

## Project Architecture

This project follows a clean, layered architecture designed for maintainability and future extensibility:

### Component Overview

```
┌─────────────────────────┐
│     iOS App Layer       │  SwiftUI Views, ViewModels
├─────────────────────────┤
│    Service Layer        │  GameService, Business Logic
├─────────────────────────┤
│   Repository Layer      │  Data Persistence (Core Data)
├─────────────────────────┤
│  ConwayGameEngine Pkg   │  Pure Game Logic, CLI
└─────────────────────────┘
```

### Key Components

**ConwayGameEngine Package** (`ConwayGameEngine/`)
- `GameEngineConfiguration.swift`: Configurable rule sets and simulation parameters
- `PlaySpeedConfiguration.swift`: Animation timing configuration for iOS and CLI
- `GameEngine.swift`: Core Conway's Game of Life computation with configurable rules
- `ConvergenceDetector.swift`: Detects cycles and stable states
- `Patterns.swift`: Predefined patterns (glider, pulsar, etc.)
- `ConwayCLI/`: Terminal executable for simulations with configuration options

**iOS App** (`ConwayGame/`)
- `Models/`: Core Data entities (`Board`, `GameState`)
- `Services/`: Business logic orchestration (`GameService`)
- `Repository/`: Data persistence abstraction
- `ViewModels/`: SwiftUI MVVM coordinators
- `Views/`: SwiftUI user interface
- `Utils/`: Shared utilities, dependency injection (`FactoryContainer`), theming (`ThemeManager`), error handling (`ErrorAlertModifier`), caching (`LRUCache`), design tokens (`DesignTokens`)

### Design Patterns

- **Protocol-oriented design**: All major components are protocol-based for testability
- **Repository pattern**: Abstracts data persistence
- **MVVM**: ViewModels coordinate between UI and services
- **Configuration management**: Centralized system eliminates magic numbers across platforms
- **Dependency Injection**: `FactoryContainer` manages object graph and configurations using FactoryKit
- **Async/await**: Modern concurrency throughout

## Development Workflow

### Git Practices

1. **Branch naming**
   - `feature/description` for new features
   - `fix/description` for bug fixes
   - `refactor/description` for code improvements
   - `docs/description` for documentation

2. **Commit messages**
   - Use concise, descriptive one-line messages
   - Start with a verb: `add`, `fix`, `update`, `refactor`, etc.
   - Examples: `add convergence detection to game engine`, `fix memory leak in board repository`

3. **Pull Request process**
   - Create feature branch from `main`
   - Ensure all tests pass
   - Include descriptive PR title and summary
   - Link any related issues
   - Request review from maintainers

### Code Standards

**Swift Style**
- Follow Swift API Design Guidelines
- Use meaningful names for types, methods, and variables
- Prefer `struct` over `class` when possible
- Use `@inline(__always)` only for performance-critical hot paths

**Architecture Principles**
- Keep game logic UI-independent
- Use protocols for testability and dependency injection
- Separate concerns across architectural layers
- Handle errors with typed enumerations (`GameError`)
- Eliminate magic numbers through centralized configuration
- Ensure cross-platform consistency via shared configuration

**Performance Guidelines**
- Use identity checking in game engine (return same instance when unchanged)
- Implement early termination for stable states
- Run long computations on background queues
- Use efficient state hashing for cycle detection

## Testing

### Running Tests

**iOS App Tests**
```bash
# All tests
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Specific test target
xcodebuild -scheme ConwayGameTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test

# Specific test class
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests

# Specific test method
xcodebuild -scheme ConwayGame -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:ConwayGameTests/GameEngineTests/testBasicPatterns
```

**Swift Package Tests**
```bash
cd ConwayGameEngine
swift test
```

### Test Structure

- `GameEngineTests.swift`: Core Conway's Game logic, edge cases, patterns
- `GameServiceTests.swift`: Service layer integration tests
- `ConvergenceDetectorTests.swift`: Convergence detection algorithms
- `BoardRepositoryTests.swift`: Persistence layer tests
- `ViewModelTests.swift`: UI logic tests
- `ConwayGameEngineTests/`: Swift Package unit tests

### Writing Tests

**Unit Tests**
- Test individual components in isolation
- Use dependency injection and mocking
- Focus on edge cases and error conditions
- Maintain >90% code coverage for core logic

**Integration Tests**
- Test component interactions
- Verify data persistence workflows
- Test complete user scenarios

**Performance Tests**
- Measure computation times for large grids
- Verify memory usage patterns
- Test convergence detection efficiency

## Building & Validation

### Build Commands

```bash
# Debug build
xcodebuild -scheme ConwayGame -configuration Debug build

# Release build
xcodebuild -scheme ConwayGame -configuration Release build

# Clean build
xcodebuild -scheme ConwayGame clean

# Swift Package build
cd ConwayGameEngine && swift build

# CLI release build
cd ConwayGameEngine && swift build -c release
```

### Pre-submission Checklist

Before submitting a pull request:

- [ ] All tests pass (iOS app and Swift Package)
- [ ] Code follows Swift style guidelines
- [ ] New features include comprehensive tests
- [ ] Documentation is updated if needed
- [ ] No breaking changes to public APIs
- [ ] Performance benchmarks are maintained
- [ ] No sensitive data or secrets in code

## Contributing Areas

We welcome contributions in these areas:

### Core Engine Enhancements
- **Additional game rules**: Add new rule variants beyond Conway, HighLife, and Day and Night
- **Configuration extensions**: Add new configurable parameters to GameEngineConfiguration
- **Performance optimizations**: Improve large grid computation
- **Pattern library**: Add more interesting predefined patterns
- **Algorithm improvements**: Enhanced convergence detection

### iOS App Features
- **Export capabilities**: Save animations as GIF/video
- **Pattern sharing**: Import/export custom patterns
- **Visualization options**: Different color schemes, zoom controls
- **Accessibility**: VoiceOver support, dynamic type
- **iPad optimization**: Better use of screen real estate

### Development Tools
- **Testing improvements**: More comprehensive test coverage
- **Documentation**: API documentation, tutorials
- **CI/CD**: Automated testing and deployment
- **Performance monitoring**: Benchmarking suite

### Bug Fixes
- Check the Issues tab for known bugs
- Include reproduction steps in bug reports
- Add regression tests for fixed bugs

## Code Review Process

### For Contributors
1. Ensure your code is well-tested and documented
2. Keep PRs focused and reasonably sized
3. Respond promptly to review feedback
4. Be open to suggestions and alternative approaches

### Review Criteria
- **Correctness**: Does the code work as intended?
- **Architecture**: Does it follow project patterns?
- **Testing**: Are changes adequately tested?
- **Performance**: Any negative impact on app performance?
- **Security**: No exposed secrets or vulnerabilities?

## Getting Help

### Questions & Discussion
- Open an issue for bugs or feature requests
- Use discussions for architecture questions
- Reference specific files and line numbers when possible

### Code Questions
- Include relevant code snippets
- Describe expected vs. actual behavior
- Mention iOS version and Xcode version

### Debugging Tips
- Use `OSLog` framework for logging (see `Utils/Logging.swift`)
- Enable Core Data debug output for persistence issues
- Use Xcode Instruments for performance analysis

## Security Guidelines

- **Never commit secrets**: API keys, certificates, passwords
- **Validate user inputs**: Especially board dimensions and generation counts
- **Secure data handling**: Follow iOS data protection guidelines
- **Dependencies**: Keep Swift Package dependencies minimal and audited

## Performance Considerations

### Memory Management
- Use `@inline(__always)` sparingly, only for proven hot paths
- Prefer value types (`struct`) over reference types (`class`)
- Be mindful of retain cycles in closures

### Computation Efficiency
- Game engine returns identity when no changes occur
- Early termination prevents infinite computation
- Background queues for long-running simulations
- Efficient bit-packed state hashing for cycle detection

### UI Responsiveness
- Keep UI updates on main queue
- Use `@MainActor` for view model properties
- Debounce rapid user interactions

## License

By contributing to this project, you agree that your contributions will be licensed under the same terms as the project.

---

Thank you for contributing to Conway's Game of Life! Your help makes this project better for everyone.