import Foundation

enum UIConstants {
    // Max board dimension for creation/editing
    static let maxBoardDimension: Int = 50
    // Max auto steps when playing continuously
    static let maxAutoStepsPerRun: Int = 500
    // Safety caps for expensive computations
    static let maxFinalIterations: Int = 10_000
    static let maxJumpGeneration: Int = 100_000
}

