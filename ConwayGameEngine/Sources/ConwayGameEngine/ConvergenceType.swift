import Foundation

/// Represents the convergence state of a Conway's Game of Life simulation.
///
/// `ConvergenceType` categorizes the final state that a cellular automaton
/// simulation reaches, enabling applications to understand and respond to
/// different termination conditions. This is essential for both performance
/// optimization and user experience in game simulations.
///
/// ## Convergence Categories
/// - **Continuing**: Simulation is actively evolving and hasn't reached a stable state
/// - **Extinct**: All cells have died, resulting in an empty grid
/// - **Cyclical**: Pattern repeats in a cycle, including still lifes (period 1) and oscillators
///
/// ## Usage Example
/// ```swift
/// switch convergenceType {
/// case .continuing:
///     // Keep simulating
/// case .extinct:
///     print("All life has ended")
/// case .cyclical(let period):
///     print("Pattern repeats every \(period) generations")
/// }
/// ```
public enum ConvergenceType: Codable, Equatable, Sendable {
    /// The simulation is still evolving and hasn't reached a stable state
    case continuing

    /// All cells have died, resulting in an empty grid with no future evolution
    case extinct

    /// The pattern has entered a repeating cycle
    ///
    /// - Parameter period: The length of the cycle in generations.
    ///   A period of 1 indicates a still life (no change between generations).
    ///   A period of 0 indicates a detected cycle but period calculation wasn't performed.
    case cyclical(period: Int)

    /// Human-readable description of the convergence state.
    ///
    /// Provides localized display text suitable for user interfaces:
    /// - "Continuing" for active simulations
    /// - "Extinct" for dead populations
    /// - "Cyclical" or "Cyclical (period N)" for repeating patterns
    public var displayName: String {
        switch self {
        case .continuing:
            "Continuing"
        case .extinct:
            "Extinct"
        case let .cyclical(period):
            period == 0 ? "Cyclical" : "Cyclical (period \(period))"
        }
    }
}
