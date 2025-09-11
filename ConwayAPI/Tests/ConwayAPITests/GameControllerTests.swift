import XCTVapor
import XCTest
@testable import ConwayAPI
import ConwayGameEngine

final class GameControllerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        try await app.asyncShutdown()
    }
    
    // MARK: - Step Endpoint Tests
    
    func testGameStepWithValidGrid() async throws {
        let blinkerGrid = [
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, false, false, false]
        ]
        
        let request = GameStepRequest(grid: blinkerGrid, rules: "conway")
        
        let response: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertEqual(response.generation, 1)
        XCTAssertEqual(response.population, 3)
        XCTAssertTrue(response.hasChanged)
        
        // Expected result: horizontal blinker
        let expectedGrid = [
            [false, false, false, false, false],
            [false, false, false, false, false],
            [false, true, true, true, false],
            [false, false, false, false, false],
            [false, false, false, false, false]
        ]
        XCTAssertEqual(response.grid, expectedGrid)
    }
    
    func testGameStepWithInvalidGrid() async throws {
        let invalidGrid = [
            [false, true],
            [false, true, false] // Inconsistent width
        ]
        
        let request = GameStepRequest(grid: invalidGrid, rules: "conway")
        
        _ = try await app.perform(.POST, "api/game/step", expecting: .badRequest) { req in
            try req.content.encode(request)
        }
    }
    
    func testGameStepWithDifferentRules() async throws {
        let grid = [
            [false, true, false],
            [true, true, true],
            [false, true, false]
        ]
        
        let request = GameStepRequest(grid: grid, rules: "highlife")
        
        let response: GameStepResponse = try await app.decode(.POST, "api/game/step", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertEqual(response.generation, 1)
        XCTAssertGreaterThanOrEqual(response.population, 0)
    }
    
    // MARK: - Simulation Endpoint Tests
    
    func testGameSimulationWithoutHistory() async throws {
        let gliderGrid = [
            [false, false, true, false],
            [false, false, false, true],
            [false, true, true, true]
        ]
        
        let request = GameSimulationRequest(
            grid: gliderGrid,
            generations: 4,
            rules: "conway",
            includeHistory: false
        )
        
        let response: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertEqual(response.generationsRun, 4)
        XCTAssertEqual(response.initialGrid, gliderGrid)
        XCTAssertNil(response.history)
        XCTAssertGreaterThanOrEqual(response.finalPopulation, 0)
    }
    
    func testGameSimulationWithHistory() async throws {
        let blinkerGrid = [
            [false, true, false],
            [false, true, false],
            [false, true, false]
        ]
        
        let request = GameSimulationRequest(
            grid: blinkerGrid,
            generations: 3,
            rules: "conway",
            includeHistory: true
        )
        
        let response: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertNotNil(response.history)
        XCTAssertGreaterThan(response.history!.count, 0)
        XCTAssertEqual(response.history!.first!.generation, 0)
    }
    
    func testGameSimulationConvergence() async throws {
        let blockGrid = [
            [false, false, false, false],
            [false, true, true, false],
            [false, true, true, false],
            [false, false, false, false]
        ]
        
        let request = GameSimulationRequest(
            grid: blockGrid,
            generations: 5,
            rules: "conway",
            includeHistory: false
        )
        
        let response: GameSimulationResponse = try await app.decode(.POST, "api/game/simulate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        // Block is a still life, should remain unchanged
        XCTAssertEqual(response.finalGrid, blockGrid)
        XCTAssertEqual(response.finalPopulation, 4)
    }
    
    func testGameSimulationInvalidGenerations() async throws {
        let grid = [[true]]
        
        let request = GameSimulationRequest(
            grid: grid,
            generations: -1,
            rules: "conway",
            includeHistory: false
        )
        
        _ = try await app.perform(.POST, "api/game/simulate", expecting: .badRequest) { req in
            try req.content.encode(request)
        }
    }
    
    func testGameSimulationTooManyGenerations() async throws {
        let grid = [[true]]
        
        let request = GameSimulationRequest(
            grid: grid,
            generations: 1001,
            rules: "conway",
            includeHistory: false
        )
        
        _ = try await app.perform(.POST, "api/game/simulate", expecting: .badRequest) { req in
            try req.content.encode(request)
        }
    }
    
    // MARK: - Validation Endpoint Tests
    
    func testValidateValidGrid() async throws {
        let validGrid = [
            [true, false, true],
            [false, true, false],
            [true, false, true]
        ]
        
        let request = GameValidationRequest(grid: validGrid)
        
        let response: ValidationResponse = try await app.decode(.POST, "api/game/validate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertTrue(response.isValid)
        XCTAssertEqual(response.width, 3)
        XCTAssertEqual(response.height, 3)
        XCTAssertEqual(response.population, 5)
        XCTAssertTrue(response.errors.isEmpty)
    }
    
    func testValidateInvalidGrid() async throws {
        let invalidGrid = [
            [true, false],
            [false, true, false] // Inconsistent width
        ]
        
        let request = GameValidationRequest(grid: invalidGrid)
        
        let response: ValidationResponse = try await app.decode(.POST, "api/game/validate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertFalse(response.isValid)
        XCTAssertNotNil(response.width)
        XCTAssertNotNil(response.height)
        XCTAssertNil(response.population)
        XCTAssertFalse(response.errors.isEmpty)
    }
    
    func testValidateEmptyGrid() async throws {
        let emptyGrid: [[Bool]] = []
        
        let request = GameValidationRequest(grid: emptyGrid)
        
        let response: ValidationResponse = try await app.decode(.POST, "api/game/validate", expecting: .ok) { req in
            try req.content.encode(request)
        }
        XCTAssertFalse(response.isValid)
        XCTAssertFalse(response.errors.isEmpty)
    }
}
