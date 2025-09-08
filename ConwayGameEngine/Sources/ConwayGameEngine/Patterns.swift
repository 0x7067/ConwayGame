import Foundation

public enum Pattern: String, CaseIterable, Identifiable {
    case block
    case beehive
    case blinker
    case toad
    case beacon
    case glider
    case pulsar
    case gospergun
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .block: return "Block"
        case .beehive: return "Beehive"
        case .blinker: return "Blinker"
        case .toad: return "Toad"
        case .beacon: return "Beacon"
        case .glider: return "Glider"
        case .pulsar: return "Pulsar"
        case .gospergun: return "Gosper Glider Gun"
        }
    }
    
    public var description: String {
        switch self {
        case .block:
            return "A simple 2x2 still life that never changes."
        case .beehive:
            return "A stable hexagonal still life pattern."
        case .blinker:
            return "The simplest oscillator with period 2."
        case .toad:
            return "A period-2 oscillator that resembles a toad."
        case .beacon:
            return "A period-2 oscillator made of two blocks."
        case .glider:
            return "The smallest spaceship that travels diagonally."
        case .pulsar:
            return "A period-3 oscillator with complex behavior."
        case .gospergun:
            return "A gun that continuously produces gliders."
        }
    }
    
    public var category: PatternCategory {
        switch self {
        case .block, .beehive:
            return .stillLife
        case .blinker, .toad, .beacon, .pulsar:
            return .oscillator
        case .glider:
            return .spaceship
        case .gospergun:
            return .gun
        }
    }
    
    public var cells: CellsGrid {
        switch self {
        case .block:
            return PatternLibrary.block
        case .beehive:
            return PatternLibrary.beehive
        case .blinker:
            return PatternLibrary.blinker
        case .toad:
            return PatternLibrary.toad
        case .beacon:
            return PatternLibrary.beacon
        case .glider:
            return PatternLibrary.glider
        case .pulsar:
            return PatternLibrary.pulsar
        case .gospergun:
            return PatternLibrary.gosperGliderGun
        }
    }
    
    /// Get pattern by name (case-insensitive)
    public static func named(_ name: String) -> Pattern? {
        return Pattern.allCases.first { $0.rawValue.lowercased() == name.lowercased() }
    }
    
    /// Get all patterns in a specific category
    public static func `in`(category: PatternCategory) -> [Pattern] {
        return Pattern.allCases.filter { $0.category == category }
    }
}

public enum PatternCategory: String, CaseIterable {
    case stillLife = "Still Life"
    case oscillator = "Oscillator"
    case spaceship = "Spaceship"
    case gun = "Gun"
    
    public var description: String {
        switch self {
        case .stillLife:
            return "Patterns that never change"
        case .oscillator:
            return "Patterns that repeat in cycles"
        case .spaceship:
            return "Patterns that move across the grid"
        case .gun:
            return "Patterns that continuously create other patterns"
        }
    }
}

public struct PatternLibrary {
    
    // MARK: - Still Lifes
    
    public static let block: CellsGrid = [
        [false, false, false, false],
        [false, true,  true,  false],
        [false, true,  true,  false],
        [false, false, false, false]
    ]
    
    public static let beehive: CellsGrid = [
        [false, false, false, false, false, false],
        [false, false, true,  true,  false, false],
        [false, true,  false, false, true,  false],
        [false, false, true,  true,  false, false],
        [false, false, false, false, false, false]
    ]
    
    // MARK: - Oscillators
    
    public static let blinker: CellsGrid = [
        [false, false, false, false, false],
        [false, false, true,  false, false],
        [false, false, true,  false, false],
        [false, false, true,  false, false],
        [false, false, false, false, false]
    ]
    
    public static let toad: CellsGrid = [
        [false, false, false, false, false, false],
        [false, false, false, false, false, false],
        [false, false, true,  true,  true,  false],
        [false, true,  true,  true,  false, false],
        [false, false, false, false, false, false],
        [false, false, false, false, false, false]
    ]
    
    public static let beacon: CellsGrid = [
        [false, false, false, false, false, false],
        [false, true,  true,  false, false, false],
        [false, true,  false, false, false, false],
        [false, false, false, false, true,  false],
        [false, false, false, true,  true,  false],
        [false, false, false, false, false, false]
    ]
    
    public static let pulsar: CellsGrid = [
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false, false, false, true,  true,  true,  false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, false, false, true,  true,  true,  false, false, false, true,  true,  true,  false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false, false, false, true,  true,  true,  false, false, false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, true,  false, false, false, false, true,  false, true,  false, false, false, false, true,  false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false, false, false, true,  true,  true,  false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
    ]
    
    // MARK: - Spaceships
    
    public static let glider: CellsGrid = [
        [false, false, false, false, false, false, false],
        [false, false, true,  false, false, false, false],
        [false, false, false, true,  false, false, false],
        [false, true,  true,  true,  false, false, false],
        [false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false]
    ]
    
    // MARK: - Guns
    
    public static let gosperGliderGun: CellsGrid = [
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true,  false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false],
        [false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false],
        [true,  true,  false, false, false, false, false, false, false, false, true,  false, false, false, false, false, true,  false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [true,  true,  false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, true,  true,  false, false, false, false, true,  false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, true,  false, false, false, false, false, true,  false, false, false, false, false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, true,  false, false, false, true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, true,  true,  false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false]
    ]
    
    // MARK: - Utility Methods
    
    /// Get all available patterns as a dictionary
    public static var allPatterns: [String: CellsGrid] {
        return [
            "block": block,
            "beehive": beehive,
            "blinker": blinker,
            "toad": toad,
            "beacon": beacon,
            "glider": glider,
            "pulsar": pulsar,
            "gospergun": gosperGliderGun
        ]
    }
    
    /// Get pattern by name (case-insensitive)
    public static func pattern(named name: String) -> CellsGrid? {
        return allPatterns[name.lowercased()]
    }
}