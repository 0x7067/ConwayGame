import Foundation

public struct DisplayFrequency: Equatable, Codable {
    public let initialGenerations: Int
    public let subsequentInterval: Int
    
    public init(initialGenerations: Int, subsequentInterval: Int) {
        self.initialGenerations = initialGenerations
        self.subsequentInterval = subsequentInterval
    }
    
    public static let `default` = DisplayFrequency(
        initialGenerations: 10,
        subsequentInterval: 5
    )
    
    public func shouldDisplay(generation: Int) -> Bool {
        return generation <= initialGenerations || generation % subsequentInterval == 0
    }
}

public struct GameEngineConfiguration: Equatable, Codable {
    public let survivalNeighborCounts: Set<Int>
    public let birthNeighborCounts: Set<Int>
    public let defaultBoardWidth: Int
    public let defaultBoardHeight: Int
    public let defaultRandomDensity: Double
    public let maxPatternGenerations: Int
    public let displayFrequency: DisplayFrequency
    
    public init(
        survivalNeighborCounts: Set<Int> = [2, 3],
        birthNeighborCounts: Set<Int> = [3],
        defaultBoardWidth: Int = 20,
        defaultBoardHeight: Int = 15,
        defaultRandomDensity: Double = 0.25,
        maxPatternGenerations: Int = 50,
        displayFrequency: DisplayFrequency = .default
    ) {
        self.survivalNeighborCounts = survivalNeighborCounts
        self.birthNeighborCounts = birthNeighborCounts
        self.defaultBoardWidth = defaultBoardWidth
        self.defaultBoardHeight = defaultBoardHeight
        self.defaultRandomDensity = defaultRandomDensity
        self.maxPatternGenerations = maxPatternGenerations
        self.displayFrequency = displayFrequency
    }
    
    public static let `default` = GameEngineConfiguration()
    
    public static let classicConway = GameEngineConfiguration(
        survivalNeighborCounts: [2, 3],
        birthNeighborCounts: [3]
    )
    
    public static let highLife = GameEngineConfiguration(
        survivalNeighborCounts: [2, 3],
        birthNeighborCounts: [3, 6]
    )
    
    public static let dayAndNight = GameEngineConfiguration(
        survivalNeighborCounts: [3, 4, 6, 7, 8],
        birthNeighborCounts: [3, 6, 7, 8]
    )
}