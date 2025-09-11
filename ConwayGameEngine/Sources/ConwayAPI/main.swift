import Foundation
import Vapor
import ConwayGameEngine

// Minimal working Conway API
var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

// Response structures
struct HealthResponse: Content {
    let status: String
    let message: String
    let version: String
}

struct StepRequest: Content {
    let grid: [[Bool]]
}

struct StepResponse: Content {
    let grid: [[Bool]]
    let population: Int
}

// Basic health endpoint
app.get("health") { req in
    return HealthResponse(
        status: "healthy",
        message: "Conway's Game of Life API is running",
        version: "1.0.0"
    )
}

// Basic Conway step endpoint
app.post("api", "step") { req in
    let request = try req.content.decode(StepRequest.self)
    let engine = ConwayGameEngine()
    let nextGrid = engine.computeNextState(request.grid)
    
    return StepResponse(
        grid: nextGrid,
        population: nextGrid.population
    )
}

try app.run()