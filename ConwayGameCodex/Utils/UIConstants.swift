import Foundation

public enum UIConstants {
    // Max board dimension for creation/editing
    public static let maxBoardDimension: Int = 50
    // Max auto steps when playing continuously
    public static let maxAutoStepsPerRun: Int = 500
    // Safety caps for expensive computations
    public static let maxFinalIterations: Int = 10_000
    public static let maxJumpGeneration: Int = 100_000
}

