# Conway's Game of Life - iOS Implementation Plan

## Project Overview
Build a production-ready iOS app implementing Conway's Game of Life with internal API architecture. Target: Staff Mobile Engineer evaluation focusing on architecture, performance, and production readiness.

## Functional Requirements
1. **Board State Management**: Create, save, and load board configurations with unique identifiers
2. **Next State Computation**: Calculate and return the next iteration of any board
3. **Multi-Step Forward**: Calculate board state X iterations ahead efficiently
4. **Final State Detection**: Detect convergence (stable patterns, oscillators, extinction) with configurable timeout
5. **Persistence**: Maintain board states across app restarts/crashes
6. **Error Handling**: Graceful failure when final state cannot be determined

## Technical Architecture

## Technical Architecture

### Future-Proof Separation of Concerns
**Critical Design Principle**: The game logic must be completely decoupled from UI components in preparation for future fullstack evolution. The architecture should allow the game engine to be extracted into a separate module/framework without UI dependencies.

### Core Components

#### 1. Pure Game Logic Layer (Platform Agnostic)
```swift
// Pure business logic - no iOS/UI dependencies
protocol GameEngine {
    func computeNextState(_ currentState: [[Bool]]) -> [[Bool]]
    func computeStateAtGeneration(_ initialState: [[Bool]], generation: Int) -> [[Bool]]
}

protocol ConvergenceDetector {
    func checkConvergence(_ state: [[Bool]]) -> ConvergenceType
}

struct GameRules {
    static func shouldCellLive(isAlive: Bool, neighborCount: Int) -> Bool
    static func countNeighbors(_ grid: [[Bool]], x: Int, y: Int) -> Int
}
```

#### 2. Data Layer (Platform Agnostic Models)
```swift
// Models with no UI/iOS dependencies
struct Board: Codable, Identifiable, Hashable
struct GameState: Codable 
struct BoardMetadata: Codable
enum ConvergenceType: Codable

// Repository abstraction
protocol BoardRepository {
    func save(_ board: Board) async throws
    func load(id: UUID) async throws -> Board?
    func loadAll() async throws -> [Board]
    func delete(id: UUID) async throws
}
```

#### 3. Service Layer (Business Logic Coordinator)
```swift
// Orchestrates game logic and persistence - no UI dependencies
protocol GameService {
    func createBoard(_ initialState: [[Bool]]) async -> UUID
    func getNextState(boardId: UUID) async -> Result<GameState, GameError>
    func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError>
    func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError>
}

class DefaultGameService: GameService {
    private let gameEngine: GameEngine
    private let repository: BoardRepository
    private let convergenceDetector: ConvergenceDetector
    
    // Pure business logic implementation
}
```

#### 4. iOS-Specific Implementation Layer
```swift
// iOS-specific implementations
class CoreDataBoardRepository: BoardRepository
class InMemoryBoardRepository: BoardRepository // for testing

// Dependency injection container
class ServiceContainer {
    lazy var gameService: GameService = DefaultGameService(
        gameEngine: ConwayGameEngine(),
        repository: CoreDataBoardRepository(),
        convergenceDetector: DefaultConvergenceDetector()
    )
}
```

#### 5. UI Layer (iOS/SwiftUI Specific)
```swift
// UI consumes services via dependency injection
class GameViewModel: ObservableObject {
    private let gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
    }
}

struct GameBoardView: View {
    @StateObject private var viewModel: GameViewModel
    
    init(gameService: GameService) {
        _viewModel = StateObject(wrappedValue: GameViewModel(gameService: gameService))
    }
}
```

### File Structure
```
ConwayGameOfLife/
├── App/
│   ├── ConwayGameOfLifeApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Board.swift
│   ├── GameState.swift
│   └── GameError.swift
├── Services/
│   ├── GameService.swift
│   ├── GameEngine.swift
│   └── ConvergenceDetector.swift
├── Repository/
│   ├── BoardRepository.swift
│   └── CoreDataBoardRepository.swift
├── ViewModels/
│   ├── GameViewModel.swift
│   └── BoardListViewModel.swift
├── Views/
│   ├── GameBoardView.swift
│   ├── GameControlsView.swift
│   ├── BoardListView.swift
│   └── CreateBoardView.swift
├── Utils/
│   ├── Extensions.swift
│   └── Constants.swift
└── Tests/
    ├── GameEngineTests.swift
    ├── GameServiceTests.swift
    └── ConvergenceDetectorTests.swift
```

## Implementation Details

### Core Data Model
```swift
struct Board: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let width: Int
    let height: Int
    let createdAt: Date
    let currentGeneration: Int
    let cells: [[Bool]]
    let isActive: Bool
    
    // For cycle detection
    let stateHistory: [String] // Hash of previous states
}

struct GameState: Codable {
    let boardId: UUID
    let generation: Int
    let cells: [[Bool]]
    let isStable: Bool
    let populationCount: Int
}
```

### Game Engine Algorithm
```swift
class ConwayGameEngine: GameEngine {
    func computeNextState(_ currentState: [[Bool]]) -> [[Bool]] {
        // Optimized neighbor counting
        // Boundary handling
        // Memory-efficient computation
    }
    
    func computeStateAtGeneration(_ initialState: [[Bool]], generation: Int) -> [[Bool]] {
        // Fast-forward with optimizations
        // Early termination for stable states
    }
}
```

### Convergence Detection Strategy
```swift
class ConvergenceDetector {
    private var stateHistory: Set<String> = []
    private var cycleLength: Int = 0
    
    func checkConvergence(_ state: [[Bool]]) -> ConvergenceType {
        let stateHash = hashState(state)
        
        // Check for extinction
        if isExtinct(state) { return .extinct }
        
        // Check for cycles/stable states
        if stateHistory.contains(stateHash) {
            return .cyclical(period: cycleLength)
        }
        
        stateHistory.insert(stateHash)
        return .continuing
    }
}
```

## Production-Ready Features

### Performance Optimizations
- **Memory Management**: Use `autoreleasepool` for large computations
- **Background Processing**: Compute generations on background queue
- **UI Responsiveness**: Async/await patterns for long operations
- **Caching**: LRU cache for computed states
- **Lazy Loading**: Only compute visible board regions for large grids

### Error Handling
```swift
enum GameError: LocalizedError {
    case boardNotFound(UUID)
    case convergenceTimeout(maxIterations: Int)
    case invalidBoardDimensions
    case persistenceError(Error)
    case computationError(Error)
}
```

### Logging & Monitoring
```swift
import OSLog
extension Logger {
    static let gameEngine = Logger(subsystem: "ConwayGame", category: "GameEngine")
    static let persistence = Logger(subsystem: "ConwayGame", category: "Persistence")
}
```

### Testing Strategy
- **Unit Tests**: Game logic, convergence detection, state calculations
- **Integration Tests**: Service layer with mock repositories
- **UI Tests**: Basic user flows
- **Performance Tests**: Large board computations, memory usage
- **Snapshot Tests**: UI consistency across different board states

### App Lifecycle Management
- **Background/Foreground**: Pause/resume active computations
- **Memory Pressure**: Implement cache eviction strategies
- **State Restoration**: Preserve UI state across app launches

## UI/UX Design

### Main Screens
1. **Board List**: Display saved boards with preview and metadata
2. **Game Board**: Interactive grid with play/pause/step controls
3. **Create Board**: Pattern templates or manual cell placement
4. **Board Details**: Statistics, generation count, population over time

### User Interactions
- **Tap cells**: Toggle alive/dead state
- **Pinch/Zoom**: Navigate large boards
- **Play/Pause**: Animate through generations
- **Step**: Advance one generation
- **Fast Forward**: Jump to specific generation
- **Export/Import**: Share board configurations

## Development Phases

### Phase 1: Core Architecture
- Set up project structure
- Implement basic models and protocols
- Create game engine with unit tests
- Set up Core Data stack

### Phase 2: Service Layer
- Implement GameService with all required methods
- Add persistence layer
- Implement convergence detection
- Error handling and logging

### Phase 3: UI Implementation
- Create SwiftUI views and view models
- Implement interactive game board
- Add board management screens
- Handle app lifecycle events

### Phase 4: Production Polish
- Performance optimizations
- Comprehensive testing
- Documentation
- Code review and refactoring

### Phase 5: Demo Preparation
- Prepare architectural presentation
- Create sample board configurations
- Performance benchmarks
- Production readiness checklist

## Success Metrics
- **Performance**: Handle 100x100 boards smoothly
- **Memory**: Stable memory usage under pressure
- **Reliability**: No crashes during normal operation
- **Testability**: >80% code coverage
- **Maintainability**: Clear architecture and documentation

## Key Discussion Points for Interview
1. **Architecture Decisions**: Why MVVM + Repository pattern
2. **Performance Trade-offs**: Memory vs computation speed
3. **Scalability**: How to handle larger boards/more features
4. **Production Concerns**: Monitoring, debugging, maintenance
5. **iOS-Specific**: Core Data, background processing, memory management