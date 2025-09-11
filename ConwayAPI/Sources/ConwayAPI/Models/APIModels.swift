import ConwayGameEngine
import Foundation
import Vapor

// MARK: - Health and API Info Responses

/// Response model for API health check endpoints.
///
/// Provides basic service status information for monitoring and diagnostics.
struct HealthResponse: Content {
    /// Current service status (typically "healthy" or "unhealthy")
    let status: String

    /// Timestamp when the health check was performed
    let timestamp: Date

    /// API version identifier
    let version: String
}

/// Response model containing API metadata and endpoint documentation.
///
/// Provides comprehensive information about the API including available
/// endpoints, version, and links to documentation.
struct APIInfoResponse: Content {
    /// API service name
    let name: String

    /// Current API version
    let version: String

    /// Brief description of the API's purpose
    let description: String

    /// Map of endpoint names to their paths
    let endpoints: [String: String]

    /// URL or path to detailed API documentation
    let documentation: String
}

// MARK: - Game Simulation Endpoints

/// Request model for single-step game computation.
///
/// Used to advance a Conway's Game of Life grid by one generation
/// with optional rule customization.
struct GameStepRequest: Content {
    /// The current game grid as a 2D boolean array
    let grid: [[Bool]]

    /// Optional rule set name ("conway", "highlife", "daynight")
    let rules: String?

    /// Creates a game step request.
    ///
    /// - Parameters:
    ///   - grid: Current game grid state
    ///   - rules: Optional rule set identifier (defaults to Conway rules)
    init(grid: [[Bool]], rules: String? = nil) {
        self.grid = grid
        self.rules = rules
    }
}

/// Response model for single-step game computation.
///
/// Contains the computed next generation state and metadata about the transition.
struct GameStepResponse: Content {
    /// The computed next generation grid
    let grid: [[Bool]]

    /// The generation number (always 1 for single steps)
    let generation: Int

    /// Number of living cells in the result grid
    let population: Int

    /// Whether any cells changed from the previous generation
    let hasChanged: Bool
}

/// Request model for multi-generation game simulation.
///
/// Supports running Conway's Game of Life for multiple generations
/// with optional history tracking and rule customization.
struct GameSimulationRequest: Content {
    /// The starting game grid
    let grid: [[Bool]]

    /// Number of generations to simulate
    let generations: Int

    /// Optional rule set name ("conway", "highlife", "daynight")
    let rules: String?

    /// Whether to include generation-by-generation history in the response
    let includeHistory: Bool?

    /// Creates a simulation request.
    ///
    /// - Parameters:
    ///   - grid: Starting grid state
    ///   - generations: Number of generations to simulate
    ///   - rules: Optional rule set identifier
    ///   - includeHistory: Whether to return full simulation history
    init(grid: [[Bool]], generations: Int, rules: String? = nil, includeHistory: Bool? = nil) {
        self.grid = grid
        self.generations = generations
        self.rules = rules
        self.includeHistory = includeHistory
    }
}

/// Response model for multi-generation game simulation.
///
/// Contains comprehensive simulation results including initial state,
/// final state, convergence analysis, and optional generation history.
struct GameSimulationResponse: Content {
    /// The original starting grid
    let initialGrid: [[Bool]]

    /// The final computed grid after simulation
    let finalGrid: [[Bool]]

    /// Actual number of generations that were computed
    let generationsRun: Int

    /// Number of living cells in the final state
    let finalPopulation: Int

    /// Convergence analysis results
    let convergence: ConvergenceResponse

    /// Optional array of all intermediate states (if requested)
    let history: [GenerationState]?
}

/// Represents a single generation state in simulation history.
///
/// Used in simulation responses when history tracking is enabled.
struct GenerationState: Content {
    /// The generation number (0-based)
    let generation: Int

    /// The grid state at this generation
    let grid: [[Bool]]

    /// Number of living cells at this generation
    let population: Int
}

/// Response model containing convergence analysis results.
///
/// Describes whether and how a simulation reached a stable state.
struct ConvergenceResponse: Content {
    /// Type of convergence detected ("continuing", "extinct", "cyclical")
    let type: String

    /// For cyclical convergence, the length of the cycle (if known)
    let period: Int?

    /// The generation where convergence was detected
    let finalGeneration: Int
}

/// Request model for grid validation operations.
///
/// Used to validate game grid format and structure before simulation.
struct GameValidationRequest: Content {
    /// The grid to validate
    let grid: [[Bool]]
}

/// Response model for grid validation results.
///
/// Provides validation status and detailed information about the grid.
struct ValidationResponse: Content {
    /// Whether the grid is valid for game simulation
    let isValid: Bool

    /// Grid width in cells (if valid)
    let width: Int?

    /// Grid height in cells (if valid)
    let height: Int?

    /// Current population count (if valid)
    let population: Int?

    /// Array of validation error messages (if invalid)
    let errors: [String]
}

// MARK: - Pattern Library Endpoints

/// Response model containing a list of available Conway's Game of Life patterns.
///
/// Used by the patterns list endpoint to provide an overview of all
/// available predefined patterns without their grid data.
struct PatternListResponse: Content {
    /// Array of available patterns with metadata
    let patterns: [PatternInfo]
}

/// Metadata about a Conway's Game of Life pattern.
///
/// Provides pattern information without the actual grid data,
/// used for pattern discovery and selection interfaces.
struct PatternInfo: Content {
    /// Internal pattern identifier
    let name: String

    /// Human-readable pattern name
    let displayName: String

    /// Description of pattern behavior and characteristics
    let description: String

    /// Pattern category ("Still Life", "Oscillator", "Spaceship", "Gun")
    let category: String

    /// Pattern width in cells
    let width: Int

    /// Pattern height in cells
    let height: Int
}

/// Response model containing complete pattern data.
///
/// Used by individual pattern endpoints to provide both metadata
/// and the actual cell grid configuration for a specific pattern.
struct PatternResponse: Content {
    /// Internal pattern identifier
    let name: String

    /// Human-readable pattern name
    let displayName: String

    /// Description of pattern behavior and characteristics
    let description: String

    /// Pattern category ("Still Life", "Oscillator", "Spaceship", "Gun")
    let category: String

    /// The pattern's cell grid configuration
    let grid: [[Bool]]

    /// Pattern width in cells
    let width: Int

    /// Pattern height in cells
    let height: Int
}

// MARK: - Rule Configuration Endpoints

/// Response model containing available Conway's Game of Life rule sets.
///
/// Lists all supported rule variants with their configurations
/// for use in game simulations.
struct RulesListResponse: Content {
    /// Array of available rule configurations
    let rules: [RuleInfo]
}

/// Information about a specific Conway's Game of Life rule set.
///
/// Describes the survival and birth conditions for a cellular
/// automaton rule variant.
struct RuleInfo: Content {
    /// Internal rule identifier ("conway", "highlife", "daynight")
    let name: String

    /// Human-readable rule name
    let displayName: String

    /// Description of the rule set's behavior and characteristics
    let description: String

    /// Neighbor counts that allow living cells to survive
    let survivalNeighborCounts: [Int]

    /// Neighbor counts that cause dead cells to become alive
    let birthNeighborCounts: [Int]
}

// MARK: - Error Handling

/// Standard error response model for API error conditions.
///
/// Provides structured error information including error type,
/// detailed message, and timestamp for debugging and logging.
struct ErrorResponse: Content {
    /// Error type or category identifier
    let error: String

    /// Detailed human-readable error message
    let message: String

    /// Timestamp when the error occurred
    let timestamp: Date

    /// Creates a new error response with automatic timestamp.
    ///
    /// - Parameters:
    ///   - error: Error type identifier
    ///   - message: Detailed error description
    init(error: String, message: String) {
        self.error = error
        self.message = message
        self.timestamp = Date()
    }
}

// MARK: - Extensions

extension [[Bool]] {
    var gridWidth: Int? {
        isEmpty ? nil : self[0].count
    }

    var gridHeight: Int {
        count
    }

    var isValidGrid: Bool {
        guard let firstWidth = self.first?.count, firstWidth > 0 else { return false }
        for row in self {
            if row.count != firstWidth { return false }
        }
        return true
    }
}

extension ConvergenceType {
    var responseType: String {
        switch self {
        case .continuing:
            "continuing"
        case .extinct:
            "extinct"
        case .cyclical:
            "cyclical"
        }
    }
}
