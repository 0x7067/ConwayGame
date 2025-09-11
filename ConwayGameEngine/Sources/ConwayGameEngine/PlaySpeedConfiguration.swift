import Foundation

public enum PlaySpeed: String, CaseIterable, Codable {
    case normal
    case fast
    case faster
    case turbo

    public var displayName: String {
        switch self {
        case .normal: "1x"
        case .fast: "2x"
        case .faster: "4x"
        case .turbo: "8x"
        }
    }
}

public struct PlaySpeedConfiguration: Equatable, Codable {
    public let intervals: [PlaySpeed: UInt64]
    public let cliDelays: CLIDelayConfiguration

    public init(
        intervals: [PlaySpeed: UInt64] = [:],
        cliDelays: CLIDelayConfiguration = .default)
    {
        var defaultIntervals: [PlaySpeed: UInt64] = [
            .normal: 500_000_000, // 0.5 seconds
            .fast: 250_000_000, // 0.25 seconds
            .faster: 125_000_000, // 0.125 seconds
            .turbo: 62_500_000 // 0.0625 seconds
        ]

        // Override with provided intervals
        for (speed, interval) in intervals {
            defaultIntervals[speed] = interval
        }

        self.intervals = defaultIntervals
        self.cliDelays = cliDelays
    }

    public static let `default` = PlaySpeedConfiguration()

    public func interval(for speed: PlaySpeed) -> UInt64 {
        intervals[speed] ?? PlaySpeedConfiguration.default.intervals[speed]!
    }
}

public struct CLIDelayConfiguration: Equatable, Codable {
    public let simulationDelay: UInt64
    public let patternDelay: UInt64

    public init(
        simulationDelay: UInt64 = 200_000_000, // 200ms
        patternDelay: UInt64 = 100_000_000 // 100ms
    ) {
        self.simulationDelay = simulationDelay
        self.patternDelay = patternDelay
    }

    public static let `default` = CLIDelayConfiguration()
}
