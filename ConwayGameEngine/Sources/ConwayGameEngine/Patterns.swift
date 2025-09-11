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
        case .block: "Block"
        case .beehive: "Beehive"
        case .blinker: "Blinker"
        case .toad: "Toad"
        case .beacon: "Beacon"
        case .glider: "Glider"
        case .pulsar: "Pulsar"
        case .gospergun: "Gosper Glider Gun"
        }
    }

    public var description: String {
        switch self {
        case .block:
            "A simple 2x2 still life that never changes."
        case .beehive:
            "A stable hexagonal still life pattern."
        case .blinker:
            "The simplest oscillator with period 2."
        case .toad:
            "A period-2 oscillator that resembles a toad."
        case .beacon:
            "A period-2 oscillator made of two blocks."
        case .glider:
            "The smallest spaceship that travels diagonally."
        case .pulsar:
            "A period-3 oscillator with complex behavior."
        case .gospergun:
            "A gun that continuously produces gliders."
        }
    }

    public var category: PatternCategory {
        switch self {
        case .block, .beehive:
            .stillLife
        case .blinker, .toad, .beacon, .pulsar:
            .oscillator
        case .glider:
            .spaceship
        case .gospergun:
            .gun
        }
    }

    public var cells: CellsGrid {
        switch self {
        case .block:
            PatternLibrary.block
        case .beehive:
            PatternLibrary.beehive
        case .blinker:
            PatternLibrary.blinker
        case .toad:
            PatternLibrary.toad
        case .beacon:
            PatternLibrary.beacon
        case .glider:
            PatternLibrary.glider
        case .pulsar:
            PatternLibrary.pulsar
        case .gospergun:
            PatternLibrary.gosperGliderGun
        }
    }

    /// Get pattern by name (case-insensitive)
    public static func named(_ name: String) -> Pattern? {
        Pattern.allCases.first { $0.rawValue.lowercased() == name.lowercased() }
    }

    /// Get all patterns in a specific category
    public static func `in`(category: PatternCategory) -> [Pattern] {
        Pattern.allCases.filter { $0.category == category }
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
            "Patterns that never change"
        case .oscillator:
            "Patterns that repeat in cycles"
        case .spaceship:
            "Patterns that move across the grid"
        case .gun:
            "Patterns that continuously create other patterns"
        }
    }
}

public enum PatternLibrary {
    // MARK: - Still Lifes

    public static let block: CellsGrid = [
        [false, false, false, false],
        [false, true, true, false],
        [false, true, true, false],
        [false, false, false, false]
    ]

    public static let beehive: CellsGrid = [
        [false, false, false, false, false, false],
        [false, false, true, true, false, false],
        [false, true, false, false, true, false],
        [false, false, true, true, false, false],
        [false, false, false, false, false, false]
    ]

    // MARK: - Oscillators

    public static let blinker: CellsGrid = [
        [false, false, false, false, false],
        [false, false, true, false, false],
        [false, false, true, false, false],
        [false, false, true, false, false],
        [false, false, false, false, false]
    ]

    public static let toad: CellsGrid = [
        [false, false, false, false, false, false],
        [false, false, false, false, false, false],
        [false, false, true, true, true, false],
        [false, true, true, true, false, false],
        [false, false, false, false, false, false],
        [false, false, false, false, false, false]
    ]

    public static let beacon: CellsGrid = [
        [false, false, false, false, false, false],
        [false, true, true, false, false, false],
        [false, true, false, false, false, false],
        [false, false, false, false, true, false],
        [false, false, false, true, true, false],
        [false, false, false, false, false, false]
    ]

    public static let pulsar: CellsGrid = [
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            true,
            true,
            true,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    ]

    // MARK: - Spaceships

    public static let glider: CellsGrid = [
        [false, false, false, false, false, false, false],
        [false, false, true, false, false, false, false],
        [false, false, false, true, false, false, false],
        [false, true, true, true, false, false, false],
        [false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false],
        [false, false, false, false, false, false, false]
    ]

    // MARK: - Guns

    public static let gosperGliderGun: CellsGrid = [
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false
        ],
        [
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            true,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            true,
            true,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ],
        [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false,
            false
        ]
    ]

    // MARK: - Utility Methods

    /// Get all available patterns as a dictionary
    public static var allPatterns: [String: CellsGrid] {
        [
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
        allPatterns[name.lowercased()]
    }
}
