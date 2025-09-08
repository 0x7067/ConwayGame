import Foundation

public enum ConvergenceType: Codable, Equatable, Sendable {
    case continuing
    case extinct
    case cyclical(period: Int)
}