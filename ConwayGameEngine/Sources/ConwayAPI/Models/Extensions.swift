import Foundation
import ConwayGameEngine

// MARK: - Pattern Extensions for API

extension Pattern {
    func toPatternInfo() -> PatternInfo {
        let grid = self.cells
        return PatternInfo(
            name: self.rawValue,
            displayName: self.displayName,
            description: self.description,
            category: self.category.rawValue,
            width: grid.first?.count ?? 0,
            height: grid.count
        )
    }
    
    func toPatternResponse() -> PatternResponse {
        let grid = self.cells
        return PatternResponse(
            name: self.rawValue,
            displayName: self.displayName,
            description: self.description,
            category: self.category.rawValue,
            grid: grid,
            width: grid.first?.count ?? 0,
            height: grid.count
        )
    }
}

// MARK: - Game Engine Configuration Extensions

extension GameEngineConfiguration {
    static let apiConfigurations: [(String, String, String, GameEngineConfiguration)] = [
        (
            "conway",
            "Conway's Game of Life",
            "The classic Conway's Game of Life rules: B3/S23",
            .classicConway
        ),
        (
            "highlife",
            "HighLife",
            "HighLife variant: B36/S23 - births on 3 or 6 neighbors",
            .highLife
        ),
        (
            "daynight",
            "Day & Night",
            "Day & Night rules: B3678/S34678 - complex behavior",
            .dayAndNight
        )
    ]
    
    func toRuleInfo(name: String, displayName: String, description: String) -> RuleInfo {
        return RuleInfo(
            name: name,
            displayName: displayName,
            description: description,
            survivalNeighborCounts: Array(survivalNeighborCounts).sorted(),
            birthNeighborCounts: Array(birthNeighborCounts).sorted()
        )
    }
}

// MARK: - Grid Validation

extension Array where Element == Array<Bool> {
    var isValidGrid: Bool {
        guard !isEmpty else { return false }
        let expectedWidth = first?.count ?? 0
        guard expectedWidth > 0 else { return false }
        return allSatisfy { $0.count == expectedWidth }
    }
    
    var validationErrors: [String] {
        var errors: [String] = []
        
        if isEmpty {
            errors.append("Grid cannot be empty")
            return errors
        }
        
        let expectedWidth = first?.count ?? 0
        if expectedWidth == 0 {
            errors.append("Grid rows cannot be empty")
        }
        
        for (index, row) in enumerated() {
            if row.count != expectedWidth {
                errors.append("Row \(index) has inconsistent width: expected \(expectedWidth), got \(row.count)")
            }
        }
        
        return errors
    }
}