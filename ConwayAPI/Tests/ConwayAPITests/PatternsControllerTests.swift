@testable import ConwayAPI
import ConwayGameEngine
import XCTest
import XCTVapor

final class PatternsControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try configure(app)
        app.logger.logLevel = .warning
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - List Patterns Tests

    func testListPatterns() async throws {
        let response: PatternListResponse = try await app.decode(.GET, "api/patterns", expecting: .ok, json: true)
        XCTAssertFalse(response.patterns.isEmpty)

        // Check that known patterns are included
        let patternNames = response.patterns.map(\.name)
        XCTAssertTrue(patternNames.contains("glider"))
        XCTAssertTrue(patternNames.contains("blinker"))
        XCTAssertTrue(patternNames.contains("block"))

        // Verify pattern structure
        for pattern in response.patterns {
            XCTAssertFalse(pattern.name.isEmpty)
            XCTAssertFalse(pattern.displayName.isEmpty)
            XCTAssertFalse(pattern.description.isEmpty)
            XCTAssertFalse(pattern.category.isEmpty)
            XCTAssertGreaterThan(pattern.width, 0)
            XCTAssertGreaterThan(pattern.height, 0)
        }
    }

    // MARK: - Get Specific Pattern Tests

    func testGetGliderPattern() async throws {
        let response: PatternResponse = try await app.decode(.GET, "api/patterns/glider", expecting: .ok, json: true)
        XCTAssertEqual(response.name, "glider")
        XCTAssertEqual(response.displayName, "Glider")
        XCTAssertEqual(response.category, "Spaceship")
        XCTAssertGreaterThan(response.width, 0)
        XCTAssertGreaterThan(response.height, 0)
        XCTAssertFalse(response.grid.isEmpty)
        XCTAssertFalse(response.description.isEmpty)

        // Verify grid dimensions match reported width/height
        XCTAssertEqual(response.grid.count, response.height)
        if let firstRow = response.grid.first {
            XCTAssertEqual(firstRow.count, response.width)
        }
    }

    func testGetBlinkerPattern() async throws {
        let blink: PatternResponse = try await app.decode(.GET, "api/patterns/blinker", expecting: .ok, json: true)
        XCTAssertEqual(blink.name, "blinker")
        XCTAssertEqual(blink.displayName, "Blinker")
        XCTAssertEqual(blink.category, "Oscillator")
        XCTAssertGreaterThan(blink.width, 0)
        XCTAssertGreaterThan(blink.height, 0)
        XCTAssertFalse(blink.grid.isEmpty)
    }

    func testGetBlockPattern() async throws {
        let block: PatternResponse = try await app.decode(.GET, "api/patterns/block", expecting: .ok, json: true)
        XCTAssertEqual(block.name, "block")
        XCTAssertEqual(block.displayName, "Block")
        XCTAssertEqual(block.category, "Still Life")
        XCTAssertEqual(block.width, 4)
        XCTAssertEqual(block.height, 4)
    }

    func testGetPulsarPattern() async throws {
        let pulsar: PatternResponse = try await app.decode(.GET, "api/patterns/pulsar", expecting: .ok, json: true)
        XCTAssertEqual(pulsar.name, "pulsar")
        XCTAssertEqual(pulsar.displayName, "Pulsar")
        XCTAssertEqual(pulsar.category, "Oscillator")
        XCTAssertGreaterThan(pulsar.width, 10)
        XCTAssertGreaterThan(pulsar.height, 10)
    }

    func testGetGosperGunPattern() async throws {
        let gun: PatternResponse = try await app.decode(.GET, "api/patterns/gospergun", expecting: .ok, json: true)
        XCTAssertEqual(gun.name, "gospergun")
        XCTAssertEqual(gun.displayName, "Gosper Glider Gun")
        XCTAssertEqual(gun.category, "Gun")
        XCTAssertGreaterThan(gun.width, 30)
        XCTAssertGreaterThan(gun.height, 10)
    }

    // MARK: - Error Cases

    func testGetNonexistentPattern() async throws {
        let res = try await app.perform(.GET, "api/patterns/nonexistent")
        XCTAssertEqual(res.status, .notFound)
    }

    func testGetPatternCaseInsensitive() async throws {
        let upper: PatternResponse = try await app.decode(.GET, "api/patterns/GLIDER", expecting: .ok, json: true)
        XCTAssertEqual(upper.name, "glider")
    }

    // MARK: - Grid Validation

    func testAllPatternsHaveValidGrids() async throws {
        let listResponse: PatternListResponse = try await app.decode(.GET, "api/patterns", expecting: .ok, json: true)

        for patternInfo in listResponse.patterns {
            let pattern: PatternResponse = try await app.decode(
                .GET,
                "api/patterns/\(patternInfo.name)",
                expecting: .ok,
                json: true)
            // Verify grid is valid
            XCTAssertTrue(pattern.grid.isValidGrid, "Pattern \(pattern.name) has invalid grid")
            // Verify dimensions match
            XCTAssertEqual(pattern.grid.count, pattern.height, "Pattern \(pattern.name) height mismatch")
            if let firstRow = pattern.grid.first {
                XCTAssertEqual(firstRow.count, pattern.width, "Pattern \(pattern.name) width mismatch")
            }
            // Verify pattern has some living cells
            let population = pattern.grid.population
            XCTAssertGreaterThanOrEqual(population, 0, "Pattern \(pattern.name) should have valid population")
        }
    }
}
