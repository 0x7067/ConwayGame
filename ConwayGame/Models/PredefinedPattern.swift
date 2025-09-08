import Foundation

public enum PredefinedPattern: String, CaseIterable, Identifiable {
    case block
    case beehive
    case blinker
    case toad
    case beacon
    case glider

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .block: return "Block"
        case .beehive: return "Beehive"
        case .blinker: return "Blinker"
        case .toad: return "Toad"
        case .beacon: return "Beacon"
        case .glider: return "Glider"
        }
    }

    public var offsets: [(Int, Int)] {
        switch self {
        case .block:
            return [(0,0),(1,0),(0,1),(1,1)]
        case .beehive:
            return [(1,0),(2,0),(0,1),(3,1),(1,2),(2,2)]
        case .blinker:
            return [(0,0),(1,0),(2,0)]
        case .toad:
            return [(1,0),(2,0),(3,0),(0,1),(1,1),(2,1)]
        case .beacon:
            return [(0,0),(1,0),(0,1),(1,1),(2,2),(3,2),(2,3),(3,3)]
        case .glider:
            return [(1,0),(2,1),(0,2),(1,2),(2,2)]
        }
    }
}