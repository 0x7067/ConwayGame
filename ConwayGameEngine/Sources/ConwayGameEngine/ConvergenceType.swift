import Foundation

public enum ConvergenceType: Codable, Equatable, Sendable {
    case continuing
    case extinct
    case cyclical(period: Int)
    
    public var displayName: String {
        switch self {
        case .continuing:
            return "Continuing"
        case .extinct:
            return "Extinct"
        case .cyclical(let period):
            return period == 0 ? "Cyclical" : "Cyclical (period \(period))"
        }
    }
}