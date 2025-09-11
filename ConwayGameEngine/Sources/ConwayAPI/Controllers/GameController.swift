import Foundation
import Vapor
import ConwayGameEngine

struct GameController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let games = routes.grouped("api", "game")
        games.post("step", use: computeStep)
        games.post("simulate", use: runSimulation)
        games.post("validate", use: validateGrid)
    }
    
    // POST /api/game/step
    func computeStep(req: Request) async throws -> GameStepResponse {
        let stepRequest = try req.content.decode(GameStepRequest.self)
        
        // Validate grid
        guard stepRequest.grid.isValidGrid else {
            let errors = stepRequest.grid.validationErrors
            throw Abort(.badRequest, reason: "Invalid grid: \(errors.joined(separator: ", "))")
        }
        
        let configuration = stepRequest.toConfiguration()
        let engine = ConwayGameEngine(configuration: configuration)
        
        let currentGrid = stepRequest.grid
        let nextGrid = engine.computeNextState(currentGrid)
        
        // Check if the grid changed by comparing references (engine returns same instance if no change)
        let hasChanged = !(nextGrid as AnyObject === currentGrid as AnyObject)
        
        return GameStepResponse(
            grid: nextGrid,
            generation: 1,
            population: nextGrid.population,
            hasChanged: hasChanged
        )
    }
    
    // POST /api/game/simulate
    func runSimulation(req: Request) async throws -> GameSimulationResponse {
        let simulationRequest = try req.content.decode(GameSimulationRequest.self)
        
        // Validate grid
        guard simulationRequest.grid.isValidGrid else {
            let errors = simulationRequest.grid.validationErrors
            throw Abort(.badRequest, reason: "Invalid grid: \(errors.joined(separator: ", "))")
        }
        
        // Validate generations
        guard simulationRequest.generations >= 0 else {
            throw Abort(.badRequest, reason: "Generations must be non-negative")
        }
        
        guard simulationRequest.generations <= 1000 else {
            throw Abort(.badRequest, reason: "Maximum 1000 generations allowed")
        }
        
        let configuration = simulationRequest.toConfiguration()
        let engine = ConwayGameEngine(configuration: configuration)
        let detector = DefaultConvergenceDetector()
        
        let initialGrid = simulationRequest.grid
        let includeHistory = simulationRequest.includeHistory ?? false
        
        var currentGrid = initialGrid
        var history: [GenerationResponse] = []
        var stateHistory: Set<String> = []
        var finalGeneration = 0
        var convergence: ConvergenceType = .continuing
        
        // Add initial state to history if requested
        if includeHistory {
            history.append(GenerationResponse(
                generation: 0,
                grid: currentGrid,
                population: currentGrid.population
            ))
        }
        
        // Run simulation
        for generation in 1...simulationRequest.generations {
            let nextGrid = engine.computeNextState(currentGrid)
            
            // Check convergence
            convergence = detector.checkConvergence(nextGrid, history: stateHistory)
            stateHistory.insert(BoardHashing.hash(for: currentGrid))
            
            currentGrid = nextGrid
            finalGeneration = generation
            
            // Add to history if requested
            if includeHistory {
                history.append(GenerationResponse(
                    generation: generation,
                    grid: currentGrid,
                    population: currentGrid.population
                ))
            }
            
            // Stop if converged
            switch convergence {
            case .extinct, .cyclical:
                break
            case .continuing:
                continue
            }
        }
        
        return GameSimulationResponse(
            initialGrid: initialGrid,
            finalGrid: currentGrid,
            generationsRun: finalGeneration,
            finalPopulation: currentGrid.population,
            convergence: ConvergenceResponse(from: convergence, finalGeneration: finalGeneration),
            history: includeHistory ? history : nil
        )
    }
    
    // POST /api/game/validate
    func validateGrid(req: Request) async throws -> ValidationResponse {
        let validationRequest = try req.content.decode(GameValidationRequest.self)
        
        let grid = validationRequest.grid
        let isValid = grid.isValidGrid
        let errors = grid.validationErrors
        
        return ValidationResponse(
            isValid: isValid,
            width: grid.first?.count,
            height: grid.count,
            population: isValid ? grid.population : nil,
            errors: errors
        )
    }
}