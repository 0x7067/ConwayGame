import Foundation
import Vapor

public func configure(_ app: Application) throws {
    // MARK: - Middleware Configuration
    
    // Add CORS support
    app.middleware.use(CORSMiddleware())
    
    // Add content type middleware
    app.middleware.use(ContentTypeMiddleware())
    
    // Add error handling middleware
    app.middleware.use(ErrorMiddleware())
    
    // MARK: - Route Configuration
    
    // Health endpoint
    app.get("health") { req in
        return HealthResponse(
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // API info endpoint
    app.get("api") { req in
        return APIInfoResponse(
            name: "Conway's Game of Life API",
            version: "1.0.0",
            description: "A high-performance REST API for Conway's Game of Life simulation",
            endpoints: [
                "GET /health": "Health check",
                "GET /api": "API information",
                "POST /api/game/step": "Compute next generation",
                "POST /api/game/simulate": "Run full simulation",
                "POST /api/game/validate": "Validate grid",
                "GET /api/patterns": "List all patterns",
                "GET /api/patterns/{name}": "Get specific pattern",
                "GET /api/rules": "List all rules"
            ],
            documentation: "https://github.com/anthropics/ConwayGame/blob/main/ConwayAPI/README.md"
        )
    }
    
    // Register controllers
    try app.register(collection: GameController())
    try app.register(collection: PatternsController())
    try app.register(collection: RulesController())
}