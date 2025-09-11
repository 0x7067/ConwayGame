import XCTVapor
import XCTest
@testable import ConwayAPI
import ConwayGameEngine

final class RulesControllerTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        app = Application(.testing)
        try configure(app)
    }
    
    override func tearDown() async throws {
        app.shutdown()
    }
    
    // MARK: - List Rules Tests
    
    func testListRules() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            
            let response = try res.content.decode(RulesListResponse.self)
            XCTAssertFalse(response.rules.isEmpty)
            
            // Check that known rules are included
            let ruleNames = response.rules.map(\.name)
            XCTAssertTrue(ruleNames.contains("conway"))
            XCTAssertTrue(ruleNames.contains("highlife"))
            XCTAssertTrue(ruleNames.contains("daynight"))
            
            // Verify rule structure
            for rule in response.rules {
                XCTAssertFalse(rule.name.isEmpty)
                XCTAssertFalse(rule.displayName.isEmpty)
                XCTAssertFalse(rule.description.isEmpty)
                XCTAssertFalse(rule.survivalNeighborCounts.isEmpty)
                XCTAssertFalse(rule.birthNeighborCounts.isEmpty)
                
                // Verify neighbor counts are valid (0-8)
                for count in rule.survivalNeighborCounts {
                    XCTAssertTrue(count >= 0 && count <= 8, "Invalid survival neighbor count: \(count)")
                }
                for count in rule.birthNeighborCounts {
                    XCTAssertTrue(count >= 0 && count <= 8, "Invalid birth neighbor count: \(count)")
                }
            }
        })
    }
    
    // MARK: - Specific Rule Validation Tests
    
    func testConwayRulesPresent() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            guard let conwayRule = response.rules.first(where: { $0.name == "conway" }) else {
                XCTFail("Conway rules not found")
                return
            }
            
            XCTAssertEqual(conwayRule.displayName, "Conway's Game of Life")
            XCTAssertTrue(conwayRule.description.contains("B3/S23"))
            XCTAssertEqual(Set(conwayRule.survivalNeighborCounts), Set([2, 3]))
            XCTAssertEqual(Set(conwayRule.birthNeighborCounts), Set([3]))
        })
    }
    
    func testHighLifeRulesPresent() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            guard let highLifeRule = response.rules.first(where: { $0.name == "highlife" }) else {
                XCTFail("HighLife rules not found")
                return
            }
            
            XCTAssertEqual(highLifeRule.displayName, "HighLife")
            XCTAssertTrue(highLifeRule.description.contains("B36/S23"))
            XCTAssertEqual(Set(highLifeRule.survivalNeighborCounts), Set([2, 3]))
            XCTAssertEqual(Set(highLifeRule.birthNeighborCounts), Set([3, 6]))
        })
    }
    
    func testDayAndNightRulesPresent() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            guard let dayNightRule = response.rules.first(where: { $0.name == "daynight" }) else {
                XCTFail("Day & Night rules not found")
                return
            }
            
            XCTAssertEqual(dayNightRule.displayName, "Day & Night")
            XCTAssertTrue(dayNightRule.description.contains("B3678/S34678"))
            XCTAssertEqual(Set(dayNightRule.survivalNeighborCounts), Set([3, 4, 6, 7, 8]))
            XCTAssertEqual(Set(dayNightRule.birthNeighborCounts), Set([3, 6, 7, 8]))
        })
    }
    
    // MARK: - Rule Consistency Tests
    
    func testRulesArrayIsSorted() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            for rule in response.rules {
                // Neighbor counts should be sorted
                XCTAssertEqual(rule.survivalNeighborCounts, rule.survivalNeighborCounts.sorted())
                XCTAssertEqual(rule.birthNeighborCounts, rule.birthNeighborCounts.sorted())
            }
        })
    }
    
    func testRulesHaveUniqueNames() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            let names = response.rules.map(\.name)
            let uniqueNames = Set(names)
            
            XCTAssertEqual(names.count, uniqueNames.count, "Rule names should be unique")
        })
    }
    
    func testRulesMatchGameEngineConfigurations() async throws {
        try app.test(.GET, "api/rules", afterResponse: { res in
            let response = try res.content.decode(RulesListResponse.self)
            
            // Verify that the API rules match the actual GameEngineConfiguration presets
            for rule in response.rules {
                let config: GameEngineConfiguration
                switch rule.name {
                case "conway":
                    config = .classicConway
                case "highlife":
                    config = .highLife
                case "daynight":
                    config = .dayAndNight
                default:
                    XCTFail("Unknown rule name: \(rule.name)")
                    continue
                }
                
                XCTAssertEqual(Set(rule.survivalNeighborCounts), config.survivalNeighborCounts)
                XCTAssertEqual(Set(rule.birthNeighborCounts), config.birthNeighborCounts)
            }
        })
    }
}