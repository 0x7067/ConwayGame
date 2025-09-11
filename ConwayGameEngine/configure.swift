import Foundation
import Vapor

public func configure(_ app: Application) throws {
    // Configure JSON encoder/decoder
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    
    // Configure CORS for API access
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)
    
    // Error handling middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // Register routes
    try routes(app)
}

func routes(_ app: Application) throws {
    // Health check endpoint
    app.get("health") { req async in
        struct HealthResponse: Content {
            let status: String
            let timestamp: Date
            let version: String
        }
        return HealthResponse(
            status: "healthy",
            timestamp: Date(),
            version: "1.0.0"
        )
    }
    
    // API Info endpoint
    app.get("api") { req async in
        struct APIInfoResponse: Content {
            let name: String
            let version: String
            let description: String
            let endpoints: [String: String]
            let documentation: String
        }
        return APIInfoResponse(
            name: "Conway's Game of Life API",
            version: "1.0.0",
            description: "REST API for Conway's Game of Life simulation",
            endpoints: [
                "GET /health": "Health check",
                "GET /api": "API information",
                "POST /api/game/step": "Compute next generation",
                "POST /api/game/simulate": "Run full simulation",
                "POST /api/game/validate": "Validate grid format",
                "GET /api/patterns": "List available patterns",
                "GET /api/patterns/:name": "Get specific pattern",
                "GET /api/rules": "List available rule configurations"
            ],
            documentation: "See README.md for detailed API documentation"
        )
    }
    
    // Register controllers
    try app.register(collection: GameController())
    try app.register(collection: PatternsController())
    try app.register(collection: RulesController())
}