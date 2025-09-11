import XCTVapor
import XCTest
@testable import ConwayAPI
import ConwayGameEngine

final class APIIntegrationTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    // MARK: - Health and Info Endpoints
    
    func testHealthEndpoint() async throws {
        try app.test(.GET, "health", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType, .json)
            
            struct HealthResponse: Codable {
                let status: String
                let timestamp: Date
                let version: String
            }
            let response = try res.content.decode(HealthResponse.self)
            XCTAssertEqual(response.status, "healthy")
            XCTAssertEqual(response.version, "1.0.0")
        })
    }
    
    func testAPIInfoEndpoint() async throws {
        try app.test(.GET, "api", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.headers.contentType, .json)
            
            struct APIInfoResponse: Codable {
                let name: String
                let version: String
                let description: String
                let endpoints: [String: String]
                let documentation: String
            }
            let response = try res.content.decode(APIInfoResponse.self)
            XCTAssertEqual(response.name, "Conway's Game of Life API")
            XCTAssertEqual(response.version, "1.0.0")
            XCTAssertFalse(response.endpoints.isEmpty)
        })
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteGliderWorkflow() async throws {
        // 1. Get glider pattern
        var gliderGrid: [[Bool]]!
        
        try app.test(.GET, "api/patterns/glider", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let pattern = try res.content.decode(PatternResponse.self)
            gliderGrid = pattern.grid
        })
        
        // 2. Validate the pattern
        let validationRequest = GameValidationRequest(grid: gliderGrid)
        
        try app.test(.POST, "api/game/validate", beforeRequest: { req in
            try req.content.encode(validationRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let validation = try res.content.decode(ValidationResponse.self)
            XCTAssertTrue(validation.isValid)
            XCTAssertGreaterThan(validation.population ?? 0, 0)
        })
        
        // 3. Run a single step
        let stepRequest = GameStepRequest(grid: gliderGrid, rules: "conway")
        
        try app.test(.POST, "api/game/step", beforeRequest: { req in
            try req.content.encode(stepRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let step = try res.content.decode(GameStepResponse.self)
            XCTAssertTrue(step.hasChanged)
            XCTAssertEqual(step.generation, 1)
        })
        
        // 4. Run full simulation
        let simulationRequest = GameSimulationRequest(
            grid: gliderGrid,
            generations: 4,
            rules: "conway",
            includeHistory: true
        )
        
        try app.test(.POST, "api/game/simulate", beforeRequest: { req in
            try req.content.encode(simulationRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let simulation = try res.content.decode(GameSimulationResponse.self)
            XCTAssertEqual(simulation.generationsRun, 4)
            XCTAssertNotNil(simulation.history)
            XCTAssertEqual(simulation.history!.count, 5) // 0-4 generations
        })
    }
    
    func testOscillatorDetection() async throws {
        // Test with blinker pattern (2-cycle oscillator)
        var blinkerGrid: [[Bool]]!
        
        try app.test(.GET, "api/patterns/blinker", afterResponse: { res in
            let pattern = try res.content.decode(PatternResponse.self)
            blinkerGrid = pattern.grid
        })
        
        let simulationRequest = GameSimulationRequest(
            grid: blinkerGrid,
            generations: 10,
            rules: "conway",
            includeHistory: false
        )
        
        try app.test(.POST, "api/game/simulate", beforeRequest: { req in
            try req.content.encode(simulationRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let simulation = try res.content.decode(GameSimulationResponse.self)
            
            // Blinker should be detected as cyclical
            XCTAssertEqual(simulation.convergence.type, "cyclical")
            XCTAssertLessThan(simulation.generationsRun, 10) // Should converge early
        })
    }
    
    func testStillLifeDetection() async throws {
        // Test with block pattern (still life)
        var blockGrid: [[Bool]]!
        
        try app.test(.GET, "api/patterns/block", afterResponse: { res in
            let pattern = try res.content.decode(PatternResponse.self)
            blockGrid = pattern.grid
        })
        
        let simulationRequest = GameSimulationRequest(
            grid: blockGrid,
            generations: 5,
            rules: "conway",
            includeHistory: false
        )
        
        try app.test(.POST, "api/game/simulate", beforeRequest: { req in
            try req.content.encode(simulationRequest)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let simulation = try res.content.decode(GameSimulationResponse.self)
            
            // Block should remain unchanged
            XCTAssertEqual(simulation.initialGrid, simulation.finalGrid)
            XCTAssertEqual(simulation.finalPopulation, 4) // Block has 4 cells
        })
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
            
            try app.test(.POST, "api/game/step", beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                XCTAssertEqual(res.status, .ok)
                let response = try res.content.decode(GameStepResponse.self)
                results[rule] = response
            })
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
        try app.test(.OPTIONS, "api/patterns", beforeRequest: { req in
            req.headers.add(name: .origin, value: "https://example.com")
            req.headers.add(name: .accessControlRequestMethod, value: "GET")
        }, afterResponse: { res in
            XCTAssertTrue(res.headers.contains(name: .accessControlAllowOrigin))
            XCTAssertTrue(res.headers.contains(name: .accessControlAllowMethods))
        })
    }
    
    func testJSONContentType() async throws {
        try app.test(.GET, "api/patterns", afterResponse: { res in
            XCTAssertEqual(res.headers.contentType, .json)
        })
        
        try app.test(.GET, "health", afterResponse: { res in
            XCTAssertEqual(res.headers.contentType, .json)
        })
    }
    
    func testInvalidRoutes() async throws {
        try app.test(.GET, "nonexistent", afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
        
        try app.test(.POST, "api/invalid", afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
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
        
        try app.test(.POST, "api/game/step", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(GameStepResponse.self)
            XCTAssertGreaterThanOrEqual(response.population, 0)
        })
    }
    
    func testSimulationGenerationLimit() async throws {
        let smallGrid = [[true]]
        
        let request = GameSimulationRequest(
            grid: smallGrid,
            generations: 1000, // At the limit
            rules: "conway",
            includeHistory: false
        )
        
        try app.test(.POST, "api/game/simulate", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
        })
    }
}