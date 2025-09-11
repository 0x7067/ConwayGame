import Foundation

public enum ConvergenceType: Codable, Equatable, Sendable {
    case continuing
    case extinct
    case cyclical(period: Int)

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
