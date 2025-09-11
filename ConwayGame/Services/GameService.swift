import Foundation
import OSLog
import ConwayGameEngine

/// Service protocol for managing Conway's Game of Life board operations and simulations.
///
/// `GameService` provides the core business logic layer for Game of Life operations,
/// coordinating between the game engine, persistence layer, and convergence detection.
/// It manages the complete lifecycle of game boards from creation through simulation.
///
/// ## Core Operations
/// - **Board Creation**: Initialize new boards with custom starting states
/// - **State Progression**: Compute next generation states with persistence
/// - **Time Travel**: Jump to specific generations efficiently
/// - **Convergence Analysis**: Find final states with termination conditions
///
/// ## Error Handling
/// All methods return `Result` types or throw `GameError` for structured error handling.
/// Common error conditions include missing boards, computation failures, and convergence timeouts.
///
/// ## Usage Example
/// ```swift
/// let gameService: GameService = DefaultGameService(...)
/// 
/// // Create a new board
/// let boardId = await gameService.createBoard(initialGrid)
/// 
/// // Simulate one step
/// let nextState = await gameService.getNextState(boardId: boardId)
/// 
/// // Find the final state
/// let finalState = await gameService.getFinalState(boardId: boardId, maxIterations: 1000)
/// ```
public protocol GameService {
    /// Creates a new game board with the specified initial state.
    ///
    /// This method creates a new board entity, persists it to storage, and returns
    /// a unique identifier for future operations. The board is initialized with
    /// generation 0 and includes state history for convergence detection.
    ///
    /// - Parameter initialState: The starting grid configuration
    /// - Returns: UUID identifier for the newly created board
    ///
    /// - Note: This method logs board creation events and handles persistence errors gracefully
    func createBoard(_ initialState: CellsGrid) async -> UUID
    
    /// Computes and persists the next generation state for a board.
    ///
    /// This method advances the board by one generation, updating both the current
    /// state and the persistent board record. It includes population counting and
    /// stability detection for comprehensive state information.
    ///
    /// - Parameter boardId: Unique identifier of the board to advance
    /// - Returns: Result containing the new GameState or GameError
    ///
    /// ## State Updates
    /// - Increments generation counter
    /// - Updates cell grid with new state  
    /// - Appends state hash to history
    /// - Calculates population and stability metrics
    func getNextState(boardId: UUID) async -> Result<GameState, GameError>
    
    /// Computes the board state at a specific generation efficiently.
    ///
    /// This method calculates the game state after the specified number of generations
    /// from the board's initial state. It uses the game engine's optimized computation
    /// with early termination for stable states and cycles.
    ///
    /// - Parameters:
    ///   - boardId: Unique identifier of the board
    ///   - generation: Target generation number (0-based)
    /// - Returns: Result containing the GameState at the target generation or GameError
    ///
    /// ## Performance Notes
    /// - Does not modify the persistent board state
    /// - Uses engine optimizations for multi-generation computation
    /// - Includes stability detection between consecutive generations
    func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError>
    
    /// Finds the final convergent state of a board with iteration limits.
    ///
    /// This method runs the simulation until a stable state is reached (extinction,
    /// stable pattern, or cycle) or the maximum iteration limit is exceeded. It uses
    /// convergence detection to terminate early when possible.
    ///
    /// - Parameters:
    ///   - boardId: Unique identifier of the board
    ///   - maxIterations: Maximum number of generations to simulate
    /// - Returns: Result containing the final GameState with convergence info or GameError
    ///
    /// ## Termination Conditions
    /// - **Early Success**: Convergence detected (extinction or cycle)
    /// - **Timeout**: Maximum iterations reached without convergence
    /// - **Generation Limit**: Special handling for UI limit with living cells
    /// - **Cancellation**: Supports task cancellation for long-running operations
    func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError>
}

/// Default implementation of GameService with comprehensive error handling and logging.
///
/// `DefaultGameService` coordinates between the game engine, repository, and convergence
/// detection components to provide a complete Game of Life service layer. It includes
/// structured logging, error transformation, and performance optimizations.
///
/// ## Architecture
/// - **Game Engine**: Handles core computation and rule application
/// - **Repository**: Manages persistent board storage and retrieval
/// - **Convergence Detector**: Identifies stable states and cycles
///
/// ## Features
/// - Comprehensive error handling with structured GameError types
/// - OSLog integration for debugging and monitoring
/// - Task cancellation support for long-running operations
/// - Efficient state hashing for convergence detection
/// - Special handling for UI generation limits
///
/// ## Usage Example
/// ```swift
/// let service = DefaultGameService(
///     gameEngine: ConwayGameEngine(),
///     repository: CoreDataBoardRepository(),
///     convergenceDetector: DefaultConvergenceDetector()
/// )
/// ```
public final class DefaultGameService: GameService {
    private let gameEngine: GameEngine
    private let repository: BoardRepository
    private let convergenceDetector: ConvergenceDetector

    /// Initializes the service with required dependencies.
    ///
    /// - Parameters:
    ///   - gameEngine: The computation engine for game state transitions
    ///   - repository: Storage layer for board persistence
    ///   - convergenceDetector: Component for detecting stable states and cycles
    public init(gameEngine: GameEngine, repository: BoardRepository, convergenceDetector: ConvergenceDetector) {
        self.gameEngine = gameEngine
        self.repository = repository
        self.convergenceDetector = convergenceDetector
    }


    /// Creates a new board with automatic naming and state initialization.
    ///
    /// This implementation generates a unique board identifier, creates a Board entity
    /// with calculated dimensions, and persists it through the repository. It includes
    /// comprehensive error handling and structured logging for debugging.
    ///
    /// ## Implementation Details
    /// - Generates UUID-based board name for uniqueness
    /// - Calculates width/height from grid dimensions
    /// - Initializes state history with starting state hash
    /// - Logs success/failure events for monitoring
    /// - Gracefully handles persistence errors without propagating
    ///
    /// - Parameter initialState: Starting grid configuration
    /// - Returns: UUID identifier that can be used for future operations
    public func createBoard(_ initialState: CellsGrid) async -> UUID {
        let id = UUID()
        let h = BoardHashing.hash(for: initialState)
        do {
            let board = try Board(
                id: id,
                name: "Board-\(id.uuidString.prefix(8))",
                width: initialState.first?.count ?? 0,
                height: initialState.count,
                cells: initialState,
                initialCells: initialState,
                stateHistory: [h]
            )
            try await repository.save(board)
            Logger.service.info("Created board: \(board.id.uuidString)")
        } catch {
            Logger.service.error("Failed to create board: \(String(describing: error))")
        }
        return id
    }

    /// Advances a board by one generation with full state persistence.
    ///
    /// This implementation loads the current board, computes the next generation using
    /// the game engine, updates all board properties, and persists the changes. It
    /// includes comprehensive state analysis and error handling.
    ///
    /// ## State Updates Performed
    /// - Computes next generation using configured game rules
    /// - Increments generation counter
    /// - Updates current cell grid state
    /// - Appends new state hash to history for cycle detection
    /// - Calculates current population count
    /// - Determines stability by checking if state would change again
    ///
    /// - Parameter boardId: Unique identifier of the board to advance
    /// - Returns: Result with GameState containing updated information or GameError
    public func getNextState(boardId: UUID) async -> Result<GameState, GameError> {
        do {
            guard var board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            // Compute next state
            let next = gameEngine.computeNextState(board.cells)
            
            // Update board state
            board.cells = next
            board.currentGeneration += 1
            board.stateHistory.append(BoardHashing.hash(for: next))
            try await repository.save(board)
            
            // Calculate properties
            let population = next.population
            let isStable = next == gameEngine.computeNextState(next)
            
            let state = GameState(
                boardId: board.id, 
                generation: board.currentGeneration, 
                cells: next, 
                isStable: isStable, 
                populationCount: population
            )
            return .success(state)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    /// Efficiently computes board state at a specific generation without persistence.
    ///
    /// This method uses the game engine's optimized multi-generation computation
    /// to calculate the state after a specified number of generations from the
    /// board's initial state. It does not modify the persistent board record.
    ///
    /// ## Performance Features
    /// - Uses engine optimizations for multi-step computation
    /// - Includes early termination for stable states and cycles
    /// - Compares consecutive generations for stability detection
    /// - No database writes for better performance
    ///
    /// - Parameters:
    ///   - boardId: Unique identifier of the board
    ///   - generation: Target generation number (0-based)
    /// - Returns: Result with GameState at target generation or GameError
    public func getStateAtGeneration(boardId: UUID, generation: Int) async -> Result<GameState, GameError> {
        do {
            guard let board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            // Use gameEngine to compute state at generation
            let state = gameEngine.computeStateAtGeneration(board.initialCells, generation: generation)
            let population = state.population
            
            // Check if stable (state unchanged from previous)
            let prevState = generation > 0 ? gameEngine.computeStateAtGeneration(board.initialCells, generation: generation - 1) : board.initialCells
            let isStable = state == prevState
            
            let gs = GameState(
                boardId: board.id, 
                generation: generation, 
                cells: state, 
                isStable: isStable, 
                populationCount: population
            )
            return .success(gs)
        } catch let e as GameError {
            return .failure(e)
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

    /// Finds the final convergent state with comprehensive termination handling.
    ///
    /// This method simulates the board until it reaches a stable state (extinction or cycle)
    /// or exceeds the iteration limit. It uses sophisticated convergence detection and
    /// supports task cancellation for responsive user interfaces.
    ///
    /// ## Convergence Detection Process
    /// 1. Maintains state history for cycle detection
    /// 2. Checks convergence conditions each generation
    /// 3. Terminates early when stable state is found
    /// 4. Handles special UI generation limit cases
    /// 5. Supports task cancellation for long operations
    ///
    /// ## Termination Conditions
    /// - **Success**: Convergence detected (extinction/cycle) with full convergence info
    /// - **Generation Limit**: UI limit exceeded with living cells (special error)
    /// - **Timeout**: General iteration limit exceeded without convergence
    /// - **Cancellation**: User or system requested operation cancellation
    ///
    /// - Parameters:
    ///   - boardId: Unique identifier of the board to simulate
    ///   - maxIterations: Maximum generations to simulate before timeout
    /// - Returns: Result with final GameState including convergence data or GameError
    public func getFinalState(boardId: UUID, maxIterations: Int) async -> Result<GameState, GameError> {
        do {
            guard let board = try await repository.load(id: boardId) else {
                return .failure(.boardNotFound(boardId))
            }
            
            var state = board.initialCells
            var history = Set<String>()
            
            for generation in 0..<maxIterations {
                if Task.isCancelled { 
                    return .failure(.computationError("Cancelled")) 
                }
                
                let hash = BoardHashing.hash(for: state)
                let convergence = convergenceDetector.checkConvergence(state, history: history)
                
                if convergence != .continuing {
                    let population = state.population
                    let gs = GameState(
                        boardId: board.id,
                        generation: generation,
                        cells: state,
                        isStable: true,
                        populationCount: population,
                        convergedAt: generation,
                        convergenceType: convergence
                    )
                    return .success(gs)
                }
                
                history.insert(hash)
                state = gameEngine.computeNextState(state)
            }
            
            // Check if we reached the generation limit with living cells
            if maxIterations >= UIConstants.maxGenerationLimit && state.population > 0 {
                return .failure(.generationLimitExceeded(maxIterations))
            }
            
            return .failure(.convergenceTimeout(maxIterations: maxIterations))
        } catch {
            return .failure(.computationError(String(describing: error)))
        }
    }

}
