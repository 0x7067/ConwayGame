import Foundation
import Vapor
import ConwayGameEngine

struct GameController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let gameRoutes = routes.grouped("api", "game")
        
        gameRoutes.post("step", use: step)
        gameRoutes.post("simulate", use: simulate)
        gameRoutes.post("validate", use: validate)
    }
    
    // MARK: - Step Endpoint
    
    func step(req: Request) async throws -> GameStepResponse {
        let request = try req.content.decode(GameStepRequest.self)
        
        // Validate grid
        try validateGrid(request.grid)
        
        // Get rule configuration
        let config = try getGameConfiguration(for: request.rules ?? "conway")
        let engine = ConwayGameEngine(configuration: config)
        
        // Compute next state
        let nextGrid = engine.computeNextState(request.grid)
        let hasChanged = !gridsEqual(request.grid, nextGrid)
        
        return GameStepResponse(
            grid: nextGrid,
            generation: 1,
            population: nextGrid.population,
            hasChanged: hasChanged
        )
    }
    
    // MARK: - Simulate Endpoint
    
    func simulate(req: Request) async throws -> GameSimulationResponse {
        let request = try req.content.decode(GameSimulationRequest.self)
        
        // Validate grid
        try validateGrid(request.grid)
        
        // Validate generations limit
        if request.generations <= 0 {
            throw Abort(.badRequest, reason: "Generations must be greater than 0")
        }
        if request.generations > 1000 {
            throw Abort(.badRequest, reason: "Maximum 1000 generations allowed")
        }
        
        // Get rule configuration
        let config = try getGameConfiguration(for: request.rules ?? "conway")
        let engine = ConwayGameEngine(configuration: config)
        let detector = DefaultConvergenceDetector()
        
        var currentGrid = request.grid
        var history: [GenerationState] = []
        let includeHistory = request.includeHistory ?? false
        var stateHistory: Set<String> = []
        
        if includeHistory {
            history.append(GenerationState(
                generation: 0,
                grid: currentGrid,
                population: currentGrid.population
            ))
        }
        
        // Add initial state to history
        stateHistory.insert(BoardHashing.hash(for: currentGrid))
        
        var generationsRun = 0
        
        for generation in 1...request.generations {
            let nextGrid = engine.computeNextState(currentGrid)
            generationsRun = generation
            
            if includeHistory {
                history.append(GenerationState(
                    generation: generation,
                    grid: nextGrid,
                    population: nextGrid.population
                ))
            }
            
            // Check convergence
            let convergence = detector.checkConvergence(nextGrid, history: stateHistory)
            
            currentGrid = nextGrid
            stateHistory.insert(BoardHashing.hash(for: currentGrid))
            
            // Stop if converged
            if convergence != .continuing {
                let period: Int?
                switch convergence {
                case .cyclical(let p):
                    period = p
                default:
                    period = nil
                }
                
                let convergenceResponse = ConvergenceResponse(
                    type: convergence.responseType,
                    period: period,
                    finalGeneration: generation
                )
                
                return GameSimulationResponse(
                    initialGrid: request.grid,
                    finalGrid: currentGrid,
                    generationsRun: generationsRun,
                    finalPopulation: currentGrid.population,
                    convergence: convergenceResponse,
                    history: includeHistory ? history : nil
                )
            }
        }
        
        // Simulation completed without convergence
        let convergenceResponse = ConvergenceResponse(
            type: ConvergenceType.continuing.responseType,
            period: nil,
            finalGeneration: generationsRun
        )
        
        return GameSimulationResponse(
            initialGrid: request.grid,
            finalGrid: currentGrid,
            generationsRun: generationsRun,
            finalPopulation: currentGrid.population,
            convergence: convergenceResponse,
            history: includeHistory ? history : nil
        )
    }
    
    // MARK: - Validate Endpoint
    
    func validate(req: Request) async throws -> ValidationResponse {
        let request = try req.content.decode(GameValidationRequest.self)
        
        do {
            try validateGrid(request.grid)
            
            return ValidationResponse(
                isValid: true,
                width: request.grid.gridWidth,
                height: request.grid.gridHeight,
                population: request.grid.population,
                errors: []
            )
        } catch let error as GridValidationError {
            return ValidationResponse(
                isValid: false,
                width: request.grid.first?.count,
                height: request.grid.count,
                population: nil,
                errors: [error.localizedDescription]
            )
        } catch {
            return ValidationResponse(
                isValid: false,
                width: nil,
                height: nil,
                population: nil,
                errors: ["Unknown validation error: \(error.localizedDescription)"]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func validateGrid(_ grid: [[Bool]]) throws {
        if grid.isEmpty {
            throw GridValidationError.emptyGrid
        }
        
        let firstRowWidth = grid[0].count
        if firstRowWidth == 0 {
            throw GridValidationError.emptyRow(0)
        }
        
        for (index, row) in grid.enumerated() {
            if row.count != firstRowWidth {
                throw GridValidationError.inconsistentWidth(
                    row: index,
                    expected: firstRowWidth,
                    actual: row.count
                )
            }
        }

        // Enforce reasonable caps to protect server resources
        let maxWidth = 200
        let maxHeight = 200
        if firstRowWidth > maxWidth || grid.count > maxHeight {
            throw GridValidationError.gridTooLarge(
                width: firstRowWidth,
                height: grid.count,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )
        }
    }
    
    private func getGameConfiguration(for ruleName: String) throws -> GameEngineConfiguration {
        switch ruleName.lowercased() {
        case "conway":
            return GameEngineConfiguration.classicConway
        case "highlife":
            return GameEngineConfiguration.highLife
        case "daynight", "day-night", "dayandnight":
            return GameEngineConfiguration.dayAndNight
        default:
            throw Abort(.badRequest, reason: "Unknown rule: \(ruleName). Available rules: conway, highlife, daynight")
        }
    }
    
    private func gridsEqual(_ grid1: [[Bool]], _ grid2: [[Bool]]) -> Bool {
        // Fast path: identical storage (engine returns original instance when unchanged)
        if (grid1 as AnyObject) === (grid2 as AnyObject) { return true }
        guard grid1.count == grid2.count else { return false }
        
        for (row1, row2) in zip(grid1, grid2) {
            guard row1.count == row2.count else { return false }
            
            for (cell1, cell2) in zip(row1, row2) {
                if cell1 != cell2 { return false }
            }
        }
        
        return true
    }
}

// MARK: - Grid Validation Errors

enum GridValidationError: LocalizedError {
    case emptyGrid
    case emptyRow(Int)
    case inconsistentWidth(row: Int, expected: Int, actual: Int)
    case gridTooLarge(width: Int, height: Int, maxWidth: Int, maxHeight: Int)
    
    var errorDescription: String? {
        switch self {
        case .emptyGrid:
            return "Grid cannot be empty"
        case .emptyRow(let row):
            return "Row \(row) cannot be empty"
        case .inconsistentWidth(let row, let expected, let actual):
            return "Row \(row) has inconsistent width: expected \(expected), got \(actual)"
        case .gridTooLarge(let width, let height, let maxW, let maxH):
            return "Grid too large: \(width)x\(height). Max allowed is \(maxW)x\(maxH)"
        }
    }
}
