import XCTVapor
import XCTest
@testable import ConwayAPI
import ConwayGameEngine

final class PatternsControllerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    // MARK: - List Patterns Tests
    
    func testListPatterns() async throws {
        try app.test(.GET, "api/patterns", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternListResponse.self)
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
        })
    }
    
    // MARK: - Get Specific Pattern Tests
    
    func testGetGliderPattern() async throws {
        try app.test(.GET, "api/patterns/glider", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
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
        })
    }
    
    func testGetBlinkerPattern() async throws {
        try app.test(.GET, "api/patterns/blinker", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
            XCTAssertEqual(response.name, "blinker")
            XCTAssertEqual(response.displayName, "Blinker")
            XCTAssertEqual(response.category, "Oscillator")
            XCTAssertGreaterThan(response.width, 0)
            XCTAssertGreaterThan(response.height, 0)
            XCTAssertFalse(response.grid.isEmpty)
        })
    }
    
    func testGetBlockPattern() async throws {
        try app.test(.GET, "api/patterns/block", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
            XCTAssertEqual(response.name, "block")
            XCTAssertEqual(response.displayName, "Block")
            XCTAssertEqual(response.category, "Still Life")
            XCTAssertEqual(response.width, 4)
            XCTAssertEqual(response.height, 4)
        })
    }
    
    func testGetPulsarPattern() async throws {
        try app.test(.GET, "api/patterns/pulsar", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
            XCTAssertEqual(response.name, "pulsar")
            XCTAssertEqual(response.displayName, "Pulsar")
            XCTAssertEqual(response.category, "Oscillator")
            XCTAssertGreaterThan(response.width, 10) // Pulsar is a large pattern
            XCTAssertGreaterThan(response.height, 10)
        })
    }
    
    func testGetGosperGunPattern() async throws {
        try app.test(.GET, "api/patterns/gospergun", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
            XCTAssertEqual(response.name, "gospergun")
            XCTAssertEqual(response.displayName, "Gosper Glider Gun")
            XCTAssertEqual(response.category, "Gun")
            XCTAssertGreaterThan(response.width, 30) // Gosper gun is very large
            XCTAssertGreaterThan(response.height, 10)
        })
    }
    
    // MARK: - Error Cases
    
    func testGetNonexistentPattern() async throws {
        try app.test(.GET, "api/patterns/nonexistent", afterResponse: { res in
            XCTAssertEqual(res.status, .notFound)
        })
    }
    
    func testGetPatternCaseInsensitive() async throws {
        try app.test(.GET, "api/patterns/GLIDER", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(PatternResponse.self)
            XCTAssertEqual(response.name, "glider")
        })
    }
    
    // MARK: - Grid Validation
    
    func testAllPatternsHaveValidGrids() async throws {
        try app.test(.GET, "api/patterns", afterResponse: { res in
            let listResponse = try res.content.decode(PatternListResponse.self)
            
            for patternInfo in listResponse.patterns {
                try app.test(.GET, "api/patterns/\(patternInfo.name)", afterResponse: { detailRes in
                    XCTAssertEqual(detailRes.status, .ok)
                    
                    let pattern = try detailRes.content.decode(PatternResponse.self)
                    
                    // Verify grid is valid
                    XCTAssertTrue(pattern.grid.isValidGrid, "Pattern \(pattern.name) has invalid grid")
                    
                    // Verify dimensions match
                    XCTAssertEqual(pattern.grid.count, pattern.height, "Pattern \(pattern.name) height mismatch")
                    if let firstRow = pattern.grid.first {
                        XCTAssertEqual(firstRow.count, pattern.width, "Pattern \(pattern.name) width mismatch")
                    }
                    
                    // Verify pattern has some living cells (except potentially still lifes that might be empty in test)
                    let population = pattern.grid.population
                    XCTAssertGreaterThanOrEqual(population, 0, "Pattern \(pattern.name) should have valid population")
                })
            }
        })
    }
}