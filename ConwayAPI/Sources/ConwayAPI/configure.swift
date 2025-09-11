import Foundation
import Vapor

public func configure(_ app: Application) throws {
    // MARK: - Configuration
    app.apiConfiguration = .fromEnvironment()
    let config = app.apiConfiguration
    
    // Configure rate limiting
    app.rateLimitConfiguration = .fromEnvironment()
    
    // Configure metrics collector
    app.metricsCollector = InMemoryMetricsCollector()
    
    // MARK: - JSON Encoding/Decoding
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)
    
    // MARK: - Middleware Configuration
    
    // Add metrics collection first (to track all requests)
    if config.enableMetrics {
        app.middleware.use(MetricsMiddleware(metrics: app.metricsCollector))
    }
    
    // Add rate limiting (after metrics, before other processing)
    if config.enableRateLimiting {
        app.middleware.use(RateLimitingMiddleware(
            config: app.rateLimitConfiguration,
            storage: InMemoryRateLimitStorage()
        ))
    }
    
    // Add CORS support with configuration
    app.middleware.use(ConfigurableCORSMiddleware(config: config))
    
    // Add content type middleware
    app.middleware.use(JSONContentTypeMiddleware())
    
    // Add error handling middleware (last, to catch all errors)
    app.middleware.use(APIErrorMiddleware())
    
    // MARK: - Route Configuration
    
    // Health endpoint
    app.get("health") { req in
        return HealthResponse(
            status: "healthy",
            timestamp: Date(),
            version: config.apiVersion
        )
    }
    
    // API info endpoint
    app.get("api") { req in
        return APIInfoResponse(
            name: "Conway's Game of Life API",
            version: config.apiVersion,
            description: "A high-performance REST API for Conway's Game of Life simulation",
            endpoints: [
                "GET /health": "Health check",
                "GET /api": "API information",
                "POST /api/game/step": "Compute next generation",
                "POST /api/game/simulate": "Run full simulation",
                "POST /api/game/validate": "Validate grid",
                "GET /api/patterns": "List all patterns",
                "GET /api/patterns/{name}": "Get specific pattern",
                "GET /api/rules": "List all rules",
                "GET /metrics": "Performance metrics (if enabled)"
            ],
            documentation: "https://github.com/0x7067/ConwayGame/blob/main/ConwayAPI/README.md"
        )
    }
    
    // Register controllers
    try app.register(collection: GameController())
    try app.register(collection: PatternsController())
    try app.register(collection: RulesController())
    
    // Register metrics endpoint if enabled
    if config.enableMetrics {
        try app.register(collection: MetricsController(metrics: app.metricsCollector))
    }
}
