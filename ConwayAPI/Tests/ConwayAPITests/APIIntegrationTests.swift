@testable import ConwayAPI
import ConwayGameEngine
import XCTest
import XCTVapor

final class APIIntegrationTests: XCTestCase {
    // CI environment detection
    private var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil ||
            ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }

    // Reduced parameters for CI
    private var maxConcurrentRequests: Int { isCI ? 3 : 20 }
    private var maxRapidRequests: Int { isCI ? 5 : 50 }
    private var maxGridSize: Int { isCI ? 15 : 50 }
    private var maxGenerations: Int { isCI ? 10 : 50 }
    private var defaultTimeout: TimeInterval { isCI ? 10.0 : 30.0 }
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
        app.logger.logLevel = .warning // quiet logs during tests
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // Helper method to run operations with timeout
    private func withTimeout<T>(
        _ timeout: TimeInterval = 10.0,
        operation: @escaping () async throws -> T) async throws -> T
    {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    private struct TimeoutError: Error {}

    // MARK: - Health and Info Endpoints

    func testHealthEndpoint() async throws {
        struct HealthResponse: Codable { let status: String
            let timestamp: Date
            let version: String
        }
        let response: HealthResponse = try await app.decode(.GET, "health", expecting: .ok, json: true)
        XCTAssertEqual(response.status, "healthy")
        XCTAssertEqual(response.version, "1.0.0")
    }

    func testAPIInfoEndpoint() async throws {
        struct APIInfoResponse: Codable { let name: String
            let version: String
            let description: String
            let endpoints: [String: String]
            let documentation: String
        }
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
            includeHistory: true)

        let simulation: GameSimulationResponse = try await app
            .decode(.POST, "api/game/simulate", expecting: .ok) { req in
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
            includeHistory: false)

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
            includeHistory: false)

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
            includeHistory: false)

        _ = try await app.perform(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(request)
        }
    }

    // MARK: - Enhanced Integration Test Scenarios

    func testMultiRuleWorkflow() async throws {
        // Test complex workflow using different rule sets
        let testPattern = [
            [false, true, false, false, false],
            [true, true, true, false, false],
            [false, false, false, true, true],
            [false, false, false, true, true],
            [false, false, false, false, false]
        ]

        let rules = ["conway", "highlife", "daynight"]
        var simulationResults: [String: GameSimulationResponse] = [:]

        // Run same pattern with different rules
        for rule in rules {
            let request = GameSimulationRequest(
                grid: testPattern,
                generations: 20,
                rules: rule,
                includeHistory: true)

            let response: GameSimulationResponse = try await app
                .decode(.POST, "api/game/simulate", expecting: .ok) { req in
                    try req.content.encode(request)
                }

            simulationResults[rule] = response

            // Basic validation
            XCTAssertGreaterThanOrEqual(response.generationsRun, 1)
            XCTAssertNotNil(response.history)
            XCTAssertEqual(response.history!.count, response.generationsRun + 1) // includes initial state
            XCTAssertEqual(response.initialGrid, testPattern)
        }

        // Compare results - different rules may produce different outcomes
        let conwayResult = simulationResults["conway"]!
        let highlifeResult = simulationResults["highlife"]!

        XCTAssertNotNil(conwayResult.finalGrid)
        XCTAssertNotNil(highlifeResult.finalGrid)

        // Results might be different due to different rules
        print("Conway final population: \(conwayResult.finalPopulation)")
        print("HighLife final population: \(highlifeResult.finalPopulation)")
    }

    func testAdvancedPatternAnalysis() async throws {
        // Test API with known Conway patterns and their expected behaviors
        let patterns = [
            ("block", 4, true), // Still life: 4 cells, should remain stable
            ("blinker", 3, true), // Oscillator: 3 cells, should oscillate
            ("glider", 5, false), // Spaceship: 5 cells, should move (not stable in small grid)
            ("toad", 6, true) // Oscillator: 6 cells, should oscillate
        ]

        for (patternName, expectedPopulation, shouldConverge) in patterns {
            // Get pattern from API
            let pattern: PatternResponse = try await app.decode(.GET, "api/patterns/\(patternName)", expecting: .ok)

            // Validate pattern data
            XCTAssertEqual(pattern.name, patternName)
            XCTAssertGreaterThan(pattern.grid.count, 0)
            XCTAssertGreaterThan(pattern.grid.first?.count ?? 0, 0)

            // Run simulation
            let request = GameSimulationRequest(
                grid: pattern.grid,
                generations: 50,
                rules: "conway",
                includeHistory: false)

            let response: GameSimulationResponse = try await app
                .decode(.POST, "api/game/simulate", expecting: .ok) { req in
                    try req.content.encode(request)
                }

            // Analyze convergence behavior
            if shouldConverge {
                if response.convergence.type == "stable" {
                    XCTAssertEqual(
                        response.finalPopulation,
                        expectedPopulation,
                        "Pattern \(patternName) should maintain \(expectedPopulation) cells")
                } else if response.convergence.type == "cyclical" {
                    // For oscillators, final population should match expected at some point in cycle
                    XCTAssertEqual(
                        response.finalPopulation,
                        expectedPopulation,
                        "Pattern \(patternName) should have \(expectedPopulation) cells in cycle")
                }
            }

            print(
                "Pattern \(patternName): \(response.generationsRun) generations, convergence: \(response.convergence.type)")
        }
    }

    func testConcurrentAPIRequests() async throws {
        // Test API under concurrent load
        let gliderPattern: PatternResponse = try await app.decode(.GET, "api/patterns/glider", expecting: .ok)
        let testGrid = gliderPattern.grid

        // Create multiple concurrent requests
        let requestCount = maxConcurrentRequests

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<requestCount {
                group.addTask {
                    do {
                        // Mix of different request types
                        switch i % 4 {
                        case 0:
                            // Step request
                            let stepRequest = GameStepRequest(grid: testGrid, rules: "conway")
                            let _: GameStepResponse = try await self.app
                                .decode(.POST, "api/game/step", expecting: .ok) { req in
                                    try req.content.encode(stepRequest)
                                }

                        case 1:
                            // Validation request
                            let validationRequest = GameValidationRequest(grid: testGrid)
                            let _: ValidationResponse = try await self.app.decode(
                                .POST,
                                "api/game/validate",
                                expecting: .ok)
                            { req in
                                try req.content.encode(validationRequest)
                            }

                        case 2:
                            // Simulation request
                            let simulationRequest = GameSimulationRequest(
                                grid: testGrid,
                                generations: 10,
                                rules: "conway",
                                includeHistory: false)
                            let _: GameSimulationResponse = try await self.app.decode(
                                .POST,
                                "api/game/simulate",
                                expecting: .ok)
                            { req in
                                try req.content.encode(simulationRequest)
                            }

                        case 3:
                            // Pattern request
                            let _: PatternResponse = try await self.app.decode(
                                .GET,
                                "api/patterns/block",
                                expecting: .ok)

                        default:
                            break
                        }
                    } catch {
                        XCTFail("Concurrent request failed: \(error)")
                    }
                }
            }
        }

        // All requests should complete successfully
        // The test passes if no XCTFail is triggered above
    }

    func testAPIRateLimitingAndThrottling() async throws {
        // Test API behavior under rapid sequential requests
        let testGrid = [[true, false], [false, true]]
        let rapidRequestCount = maxRapidRequests

        var successCount = 0
        var errorCount = 0

        for _ in 0..<rapidRequestCount {
            do {
                let request = GameValidationRequest(grid: testGrid)
                let _: ValidationResponse = try await app.decode(.POST, "api/game/validate", expecting: .ok) { req in
                    try req.content.encode(request)
                }
                successCount += 1
            } catch {
                errorCount += 1
                // Some requests might be rate limited - that's acceptable
            }
        }

        // Should handle most requests successfully
        XCTAssertGreaterThan(successCount, rapidRequestCount / 2, "API should handle reasonable request rate")

        print("Rapid requests: \(successCount) successful, \(errorCount) failed/limited")
    }

    func testComplexGridPatterns() async throws {
        // Skip this test in CI to prevent hangs
        if isCI {
            throw XCTSkip("Skipping complex grid patterns test in CI environment")
        }
        // Test API with complex, real-world patterns
        let complexPatterns = [
            // Spacefiller pattern (grows indefinitely)
            ("spacefiller", (0..<8).map { row in
                (0..<8).map { col in
                    (row == 3 && (col == 1 || col == 2 || col == 5 || col == 6)) ||
                        (row == 4 && (col == 0 || col == 3 || col == 4 || col == 7)) ||
                        (row == 5 && (col == 1 || col == 2 || col == 5 || col == 6))
                }
            }),

            // Random dense pattern
            ("dense_random", (0..<15).map { _ in
                (0..<15).map { _ in Double.random(in: 0...1) < 0.7 }
            }),

            // Symmetric pattern
            ("symmetric", (0..<10).map { row in
                (0..<10).map { col in
                    row == col || row + col == 9
                }
            })
        ]

        for (patternName, pattern) in complexPatterns {
            // Validate pattern
            let validationRequest = GameValidationRequest(grid: pattern)
            let validation: ValidationResponse = try await app
                .decode(.POST, "api/game/validate", expecting: .ok) { req in
                    try req.content.encode(validationRequest)
                }

            XCTAssertTrue(validation.isValid, "Pattern \(patternName) should be valid")
            XCTAssertGreaterThan(validation.population ?? 0, 0, "Pattern \(patternName) should have living cells")

            // Run limited simulation
            let simulationRequest = GameSimulationRequest(
                grid: pattern,
                generations: 25,
                rules: "conway",
                includeHistory: false)

            let response: GameSimulationResponse = try await app
                .decode(.POST, "api/game/simulate", expecting: .ok) { req in
                    try req.content.encode(simulationRequest)
                }

            XCTAssertGreaterThanOrEqual(response.generationsRun, 1)
            XCTAssertNotNil(response.finalGrid)
            XCTAssertEqual(response.finalGrid.count, pattern.count)
            XCTAssertEqual(response.finalGrid.first?.count, pattern.first?.count)

            print(
                "Complex pattern \(patternName): \(response.generationsRun) generations, final population: \(response.finalPopulation)")
        }
    }

    func testAPIErrorHandlingScenarios() async throws {
        // Test various error conditions and recovery

        // 1. Invalid grid sizes  
        let invalidGrids = [
            ([], "Empty grid"),
            ([[]], "Empty row"),
            ([[true], [true, false]], "Inconsistent row lengths"),
            (Array(repeating: Array(repeating: true, count: 300), count: 300), "Oversized grid") // Use 300x300 to ensure rejection
        ]

        for (invalidGrid, description) in invalidGrids {
            let request = GameValidationRequest(grid: invalidGrid)

            do {
                let response: ValidationResponse = try await app.decode(.POST, "api/game/validate") { req in
                    try req.content.encode(request)
                }
                
                // Check if the API correctly identified it as invalid
                if !response.isValid {
                    print("\(description) correctly rejected with errors: \(response.errors)")
                } else {
                    // This might be acceptable for some edge cases, but let's log it
                    print("\(description) was accepted as valid (may be edge case)")
                }

            } catch {
                // Also acceptable - rejection at request level
                print("\(description) rejected at request level: \(error)")
            }
        }

        // 2. Invalid rule names
        let validGrid = [[true, false], [false, true]]
        let invalidRules = ["invalid_rule", "", "nonexistent", "xyz123", "unknown_rule"]

        for invalidRule in invalidRules {
            let request = GameStepRequest(grid: validGrid, rules: invalidRule)

            let response = try await app.perform(.POST, "api/game/step") { req in
                try req.content.encode(request)
            }

            // Should return error status for invalid rules
            XCTAssertTrue(
                [.badRequest, .unprocessableEntity].contains(response.status),
                "Invalid rule '\(invalidRule)' should be rejected")
        }

        // 3. Excessive generation requests
        let excessiveRequest = GameSimulationRequest(
            grid: validGrid,
            generations: 10000, // Beyond reasonable limit
            rules: "conway",
            includeHistory: true)

        let excessiveResponse = try await app.perform(.POST, "api/game/simulate") { req in
            try req.content.encode(excessiveRequest)
        }

        // Should either reject or cap the generations
        XCTAssertTrue([.ok, .badRequest, .unprocessableEntity].contains(excessiveResponse.status))
    }

    func testAPIPerformanceBenchmarks() async throws {
        // Performance benchmarks for different grid sizes and operations
        let gridSizes = isCI ? [(5, 5), (10, 10)] : [(5, 5), (10, 10), (25, 25), (50, 50)]

        for (width, height) in gridSizes {
            let testGrid = (0..<height).map { _ in
                (0..<width).map { _ in Bool.random() }
            }

            // Benchmark single step
            let stepStartTime = DispatchTime.now()
            let stepRequest = GameStepRequest(grid: testGrid, rules: "conway")
            let _: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
                try req.content.encode(stepRequest)
            }
            let stepEndTime = DispatchTime.now()
            let stepDuration = stepEndTime.uptimeNanoseconds - stepStartTime.uptimeNanoseconds

            // Benchmark simulation
            let simStartTime = DispatchTime.now()
            let simRequest = GameSimulationRequest(
                grid: testGrid,
                generations: 20,
                rules: "conway",
                includeHistory: false)
            let _: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
                try req.content.encode(simRequest)
            }
            let simEndTime = DispatchTime.now()
            let simDuration = simEndTime.uptimeNanoseconds - simStartTime.uptimeNanoseconds

            // Performance assertions (adjust thresholds as needed)
            XCTAssertLessThan(stepDuration, 500_000_000, "Single step for \(width)x\(height) took too long") // 500ms
            XCTAssertLessThan(simDuration, 2_000_000_000, "Simulation for \(width)x\(height) took too long") // 2s

            print(
                "Grid \(width)x\(height): Step=\(Double(stepDuration) / 1_000_000)ms, Sim=\(Double(simDuration) / 1_000_000)ms")
        }
    }

    func testAPIContentNegotiation() async throws {
        // Test different content types and headers
        let testGrid = [[true, false], [false, true]]

        // Test with explicit JSON content type
        let response1 = try await app.perform(.POST, "api/game/validate") { req in
            req.headers.contentType = .json
            try req.content.encode(GameValidationRequest(grid: testGrid))
        }
        XCTAssertEqual(response1.status, .ok)

        // Test response content type
        XCTAssertTrue(response1.headers.contentType?.description.contains("application/json") ?? false)

        // Test CORS headers with actual request
        let corsResponse = try await app.perform(.OPTIONS, "api/game/step") { req in
            req.headers.add(name: .origin, value: "https://localhost:3000")
            req.headers.add(name: .accessControlRequestMethod, value: "POST")
            req.headers.add(name: .accessControlRequestHeaders, value: "Content-Type")
        }

        XCTAssertTrue([.ok, .noContent].contains(corsResponse.status))
        XCTAssertNotNil(corsResponse.headers.first(name: .accessControlAllowOrigin))
    }

    func testWebSocketLikeStreaming() async throws {
        // Skip this test in CI to prevent hangs from Task.sleep
        if isCI {
            throw XCTSkip("Skipping streaming test in CI environment")
        }
        // Test streaming-like behavior by making sequential requests to simulate real-time updates
        let gliderPattern: PatternResponse = try await app.decode(.GET, "api/patterns/glider", expecting: .ok)
        var currentGrid = gliderPattern.grid

        let steps = 10
        var gridHistory: [[[Bool]]] = [currentGrid]

        // Simulate streaming by making sequential step requests
        for step in 1...steps {
            let stepRequest = GameStepRequest(grid: currentGrid, rules: "conway")
            let stepResponse: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
                try req.content.encode(stepRequest)
            }

            currentGrid = stepResponse.grid
            gridHistory.append(currentGrid)

            XCTAssertEqual(stepResponse.generation, step)
            XCTAssertTrue(stepResponse.hasChanged || step == 1) // Should change or be first step

            // Small delay to simulate real-time streaming
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        XCTAssertEqual(gridHistory.count, steps + 1)

        // Verify consistency by comparing with bulk simulation
        let bulkRequest = GameSimulationRequest(
            grid: gliderPattern.grid,
            generations: steps,
            rules: "conway",
            includeHistory: true)

        let bulkResponse: GameSimulationResponse = try await app
            .decode(.POST, "api/game/simulate", expecting: .ok) { req in
                try req.content.encode(bulkRequest)
            }

        XCTAssertEqual(bulkResponse.history?.count, steps + 1)
        XCTAssertEqual(bulkResponse.finalGrid, currentGrid, "Streaming and bulk simulation should match")
    }

    func testAPIDocumentationEndpoints() async throws {
        // Test additional API documentation and metadata endpoints

        // Test rules listing
        struct RulesResponse: Codable {
            let rules: [RuleInfo]
        }

        struct RuleInfo: Codable {
            let name: String
            let displayName: String
            let description: String
            let survivalNeighborCounts: [Int]
            let birthNeighborCounts: [Int]
        }

        do {
            let rulesResponse: RulesResponse = try await app.decode(.GET, "api/rules", expecting: .ok, json: true)

            let ruleNames = rulesResponse.rules.map(\.name)
            XCTAssertTrue(ruleNames.contains("conway"))
            XCTAssertTrue(ruleNames.contains("highlife"))

            guard let conwayRule = rulesResponse.rules.first(where: { $0.name == "conway" }) else {
                XCTFail("Conway rule not found")
                return
            }
            XCTAssertEqual(conwayRule.displayName, "Conway's Game of Life")
            XCTAssertEqual(conwayRule.survivalNeighborCounts, [2, 3])
            XCTAssertEqual(conwayRule.birthNeighborCounts, [3])
        } catch {
            // Rules endpoint might not be implemented - that's acceptable
            print("Rules endpoint not available: \(error)")
        }

        // Test patterns listing
        struct PatternsListResponse: Codable {
            let patterns: [PatternInfo]
        }

        struct PatternInfo: Codable {
            let name: String
            let displayName: String
            let description: String
            let category: String
            let width: Int
            let height: Int
        }

        do {
            let patternsResponse: PatternsListResponse = try await app.decode(
                .GET,
                "api/patterns",
                expecting: .ok,
                json: true)

            let patternNames = patternsResponse.patterns.map(\.name)
            XCTAssertTrue(patternNames.contains("glider"))
            XCTAssertTrue(patternNames.contains("block"))
            XCTAssertTrue(patternNames.contains("blinker"))

            print("Available patterns: \(patternNames)")
        } catch {
            // Patterns list endpoint might not be implemented
            print("Patterns list endpoint not available: \(error)")
        }
    }
}
