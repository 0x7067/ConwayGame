import XCTest

final class ConwayGameCodexUITests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - App Launch Tests
    
    @MainActor
    func test_appLaunches_showsTabBar() throws {
        // Verify main tab bar is present
        XCTAssertTrue(app.tabBars.element.exists)
        
        // Verify main tabs are present
        XCTAssertTrue(app.tabBars.buttons["Boards"].exists)
        XCTAssertTrue(app.tabBars.buttons["Patterns"].exists)
        XCTAssertTrue(app.tabBars.buttons["About"].exists)
    }
    
    @MainActor
    func test_appLaunches_boardsTabIsSelected() throws {
        // Boards tab should be selected by default
        let boardsTab = app.tabBars.buttons["Boards"]
        XCTAssertTrue(boardsTab.isSelected)
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func test_navigation_canSwitchBetweenTabs() throws {
        // Switch to Patterns tab
        app.tabBars.buttons["Patterns"].tap()
        XCTAssertTrue(app.navigationBars["Patterns"].exists)
        
        // Switch to About tab
        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.navigationBars["About"].exists)
        
        // Switch back to Boards tab
        app.tabBars.buttons["Boards"].tap()
        XCTAssertTrue(app.navigationBars["Boards"].exists)
    }
    
    // MARK: - Boards Tab Tests
    
    @MainActor
    func test_boardsTab_hasCreateButton() throws {
        // Should have a create/add button in navigation
        XCTAssertTrue(
            app.navigationBars.buttons.matching(identifier: "Create").element.exists ||
            app.navigationBars.buttons.matching(identifier: "Add").element.exists ||
            app.navigationBars.buttons.matching(identifier: "+").element.exists
        )
    }
    
    @MainActor
    func test_boardsTab_canCreateNewBoard() throws {
        // Look for create button (could be + or "Create" or similar)
        let createButton = app.navigationBars.buttons.element(boundBy: 0)
        
        if createButton.exists {
            createButton.tap()
            
            // Should navigate to create board screen
            // Look for elements that indicate we're in create mode
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: app.navigationBars.buttons["Cancel"]
            )
            
            wait(for: [expectation], timeout: 5.0)
            XCTAssertTrue(app.navigationBars.buttons["Cancel"].exists)
        }
    }
    
    // MARK: - Patterns Tab Tests
    
    @MainActor
    func test_patternsTab_showsPatternList() throws {
        app.tabBars.buttons["Patterns"].tap()
        
        // Should show patterns information
        XCTAssertTrue(app.staticTexts["Common Patterns"].exists)
        
        // Should show some pattern names
        let patternNames = ["Still lifes", "Oscillators", "Glider"]
        for patternName in patternNames {
            XCTAssertTrue(app.staticTexts[patternName].exists)
        }
    }
    
    // MARK: - About Tab Tests
    
    @MainActor
    func test_aboutTab_showsAppInformation() throws {
        app.tabBars.buttons["About"].tap()
        
        // Should show app title and basic info
        XCTAssertTrue(app.staticTexts["Conway's Game of Life"].exists)
        XCTAssertTrue(app.staticTexts["Created by Pedro Guimarães"].exists)
        
        // Should show sections
        XCTAssertTrue(app.staticTexts["About"].exists)
        XCTAssertTrue(app.staticTexts["How It Works"].exists)
        XCTAssertTrue(app.staticTexts["Credits"].exists)
    }
    
    // MARK: - Game Flow Tests (if boards exist)
    
    @MainActor
    func test_gameFlow_canNavigateToGameIfBoardExists() throws {
        // This test assumes there might be existing boards
        // Look for any board in the list
        let firstCell = app.cells.element(boundBy: 0)
        
        if firstCell.exists {
            firstCell.tap()
            
            // Should navigate to game view
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: app.navigationBars["Game"]
            )
            
            wait(for: [expectation], timeout: 5.0)
            
            if app.navigationBars["Game"].exists {
                // Should have game controls
                let playPauseButton = app.buttons.matching(identifier: "play").element
                let stepButton = app.buttons.matching(identifier: "step").element
                
                // At least one of these should exist
                XCTAssertTrue(playPauseButton.exists || stepButton.exists)
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor
    func test_accessibility_mainElementsHaveLabels() throws {
        // Tab bar buttons should have accessibility labels
        let boardsTab = app.tabBars.buttons["Boards"]
        let patternsTab = app.tabBars.buttons["Patterns"]
        let aboutTab = app.tabBars.buttons["About"]
        
        XCTAssertNotNil(boardsTab.label)
        XCTAssertNotNil(patternsTab.label)
        XCTAssertNotNil(aboutTab.label)
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func test_performance_appLaunch() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    @MainActor
    func test_performance_tabSwitching() throws {
        measure {
            app.tabBars.buttons["Patterns"].tap()
            app.tabBars.buttons["About"].tap()
            app.tabBars.buttons["Boards"].tap()
        }
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor
    func test_errorHandling_appDoesNotCrashOnQuickActions() throws {
        // Rapidly switch between tabs
        for _ in 0..<5 {
            app.tabBars.buttons["Patterns"].tap()
            app.tabBars.buttons["About"].tap()
            app.tabBars.buttons["Boards"].tap()
        }
        
        // App should still be responsive
        XCTAssertTrue(app.tabBars.element.exists)
    }
}