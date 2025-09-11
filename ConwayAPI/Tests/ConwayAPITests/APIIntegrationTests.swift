import XCTVapor
import XCTest
@testable import ConwayAPI
import ConwayGameEngine

final class APIIntegrationTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    // MARK: - Health and Info Endpoints
    
    func testHealthEndpoint() async throws {
        struct HealthResponse: Codable { let status: String; let timestamp: Date; let version: String }
        let response: HealthResponse = try await app.decode(.GET, "health", expecting: .ok, json: true)
        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.version, "1.0.0")
    }
    
    func testAPIInfoEndpoint() async throws {
        struct APIInfoResponse: Codable { let name: String; let version: String; let description: String; let endpoints: [String: String]; let documentation: String }
        let info: APIInfoResponse = try await app.decode(.GET, "api", expecting: .ok, json: true)
        XCTAssertEqual(info.name, "Conway's Game of Life API")
        XCTAssertEqual(info.version, "1.0.0")
        XCTAssertFalse(info.endpoints.isEmpty)
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteGliderWorkflow() async throws {
        // 1. Get glider pattern
        let gliderPattern: PatternResponse = try await app.decode(.GET, "api/patterns/glider", expecting: .ok)
        let gliderGrid = gliderPattern.grid
        
        // 2. Validate the pattern
        let validationRequest = GameValidationRequest(grid: gliderGrid)
        
        let validation: ValidationResponse = try await app.decode(.POST, "api/game/validate", expecting: .ok) { req in
            try req.content.encode(validationRequest)
        }
        XCTAssertTrue(validation.isValid)
        XCTAssertGreaterThan(validation.population ?? 0, 0)
        
        // 3. Run a single step
        let stepRequest = GameStepRequest(grid: gliderGrid, rules: "conway")
        
        let step: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
            try req.content.encode(stepRequest)
        }
        XCTAssertTrue(step.hasChanged)
        XCTAssertEqual(step.generation, 1)
        
        // 4. Run full simulation
        let simulationRequest = GameSimulationRequest(
            grid: gliderGrid,
            generations: 4,
            rules: "conway",
            includeHistory: true
        )
        
        let simulation: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(simulationRequest)
        }
        XCTAssertEqual(simulation.generationsRun, 4)
        XCTAssertNotNil(simulation.history)
        XCTAssertEqual(simulation.history!.count, 5)
    }
    
    func testOscillatorDetection() async throws {
        // Test with blinker pattern (2-cycle oscillator)
        let blinkerPattern: PatternResponse = try await app.decode(.GET, "api/patterns/blinker")
        let blinkerGrid = blinkerPattern.grid
        
        let simulationRequest = GameSimulationRequest(
            grid: blinkerGrid,
            generations: 10,
            rules: "conway",
            includeHistory: false
        )
        
        let osc: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(simulationRequest)
        }
        XCTAssertEqual(osc.convergence.type, "cyclical")
        XCTAssertLessThan(osc.generationsRun, 10)
    }
    
    func testStillLifeDetection() async throws {
        // Test with block pattern (still life)
        let blockPattern: PatternResponse = try await app.decode(.GET, "api/patterns/block")
        let blockGrid = blockPattern.grid
        
        let simulationRequest = GameSimulationRequest(
            grid: blockGrid,
            generations: 5,
            rules: "conway",
            includeHistory: false
        )
        
        let still: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(simulationRequest)
        }
        XCTAssertEqual(still.initialGrid, still.finalGrid)
        XCTAssertEqual(still.finalPopulation, 4)
    }
    
    // MARK: - Cross-Rule Testing
    
    func testSamePatternDifferentRules() async throws {
        let testGrid = [
            [false, true, false],
            [true, true, true],
            [false, true, false]
        ]
        
        let rules = ["conway", "highlife", "daynight"]
        var results: [String: GameStepResponse] = [:]
        
        for rule in rules {
            let request = GameStepRequest(grid: testGrid, rules: rule)
            let resp: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
                try req.content.encode(request)
            }
            results[rule] = resp
        }
        
        // Different rules should potentially produce different results
        XCTAssertEqual(results.count, 3)
        
        // Verify all responses are valid
        for (rule, response) in results {
            XCTAssertGreaterThanOrEqual(response.population, 0, "Rule \(rule) produced invalid population")
            XCTAssertEqual(response.generation, 1)
        }
    }
    
    // MARK: - Error Handling Integration
    
    func testCORSHeaders() async throws {
        let cors = try await app.perform(.OPTIONS, "api/patterns") { req in
            req.headers.add(name: .origin, value: "https://example.com")
            req.headers.add(name: .accessControlRequestMethod, value: "GET")
        }
        XCTAssertTrue(cors.headers.contains(name: .accessControlAllowOrigin))
        XCTAssertTrue(cors.headers.contains(name: .accessControlAllowMethods))
    }
    
    func testJSONContentType() async throws {
        _ = try await app.perform(.GET, "api/patterns", expecting: .ok, json: true)
        _ = try await app.perform(.GET, "health", expecting: .ok, json: true)
    }
    
    func testInvalidRoutes() async throws {
        _ = try await app.perform(.GET, "nonexistent", expecting: .notFound)
        _ = try await app.perform(.POST, "api/invalid", expecting: .notFound)
    }
    
    // MARK: - Performance and Limits
    
    func testLargeGridHandling() async throws {
        // Create a reasonably large grid (20x20)
        let largeGrid = (0..<20).map { row in
            (0..<20).map { col in
                (row + col) % 3 == 0 // Create a pattern
            }
        }
        
        let request = GameStepRequest(grid: largeGrid, rules: "conway")
        
        let response: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertGreaterThanOrEqual(response.population, 0)
    }
    
    func testSimulationGenerationLimit() async throws {
        let smallGrid = [[true]]
        
        let request = GameSimulationRequest(
            grid: smallGrid,
            generations: 1000, // At the limit
            rules: "conway",
            includeHistory: false
        )
        
        _ = try await app.perform(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(request)
        }
}
}
