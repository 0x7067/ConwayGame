import XCTest
import ConwayGameEngine
@testable import ConwayGame

final class UserFriendlyErrorTests: XCTestCase {
    
    // MARK: - ConwayGameUserError Tests
    
    func test_boardNotFound_createsUserFriendlyError() {
        let boardId = UUID()
        let gameError = GameError.boardNotFound(boardId)
        let userError = gameError.userFriendly(context: .boardLoading)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Board Not Found")
        XCTAssertTrue(userError.userFriendlyMessage.contains("couldn't be found"))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.goToBoardList, .createNew])
        XCTAssertEqual(userError.gameError, gameError)
    }
    
    func test_convergenceTimeout_createsUserFriendlyError() {
        let maxIterations = 1000
        let gameError = GameError.convergenceTimeout(maxIterations: maxIterations)
        let userError = gameError.userFriendly(context: .gameSimulation)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Simulation Taking Too Long")
        XCTAssertTrue(userError.userFriendlyMessage.contains("\(maxIterations) steps"))
        XCTAssertTrue(userError.userFriendlyMessage.contains("complex patterns"))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.cancel, .tryAgain])
    }
    
    func test_generationLimitExceeded_createsUserFriendlyError() {
        let generations = 500
        let gameError = GameError.generationLimitExceeded(generations)
        let userError = gameError.userFriendly(context: .gameSimulation)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Simulation Limit Reached")
        XCTAssertTrue(userError.userFriendlyMessage.contains("\(generations) generations"))
        XCTAssertTrue(userError.userFriendlyMessage.contains("stable pattern"))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.resetBoard, .cancel])
    }
    
    func test_invalidBoardDimensions_createsUserFriendlyError() {
        let gameError = GameError.invalidBoardDimensions
        let userError = gameError.userFriendly(context: .boardCreation)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Invalid Board Setup")
        XCTAssertTrue(userError.userFriendlyMessage.contains("invalid dimensions"))
        XCTAssertTrue(userError.userFriendlyMessage.contains("irregular cell arrangements"))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.createNew, .goBack])
    }
    
    func test_persistenceError_createsUserFriendlyError() {
        let originalMessage = "Database connection failed"
        let gameError = GameError.persistenceError(originalMessage)
        let userError = gameError.userFriendly(context: .dataPersistence)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Saving Problem")
        XCTAssertTrue(userError.userFriendlyMessage.contains("Unable to save"))
        XCTAssertTrue(userError.userFriendlyMessage.contains(originalMessage))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.retry, .continueWithoutSaving])
    }
    
    func test_computationError_createsUserFriendlyError() {
        let originalMessage = "Memory allocation failed"
        let gameError = GameError.computationError(originalMessage)
        let userError = gameError.userFriendly(context: .gameSimulation)
        
        XCTAssertEqual(userError.userFriendlyTitle, "Simulation Error")
        XCTAssertTrue(userError.userFriendlyMessage.contains("Something went wrong"))
        XCTAssertTrue(userError.userFriendlyMessage.contains(originalMessage))
        XCTAssertNotNil(userError.recoverySuggestion)
        XCTAssertEqual(userError.recoveryActions, [.resetBoard, .tryAgain])
    }
    
    // MARK: - Context-Specific Recovery Actions Tests
    
    func test_boardNotFound_differentContexts_differentRecoveryActions() {
        let gameError = GameError.boardNotFound(UUID())
        
        let loadingContext = gameError.userFriendly(context: .boardLoading)
        XCTAssertEqual(loadingContext.recoveryActions, [.goToBoardList, .createNew])
        
        let simulationContext = gameError.userFriendly(context: .gameSimulation)
        XCTAssertEqual(simulationContext.recoveryActions, [.goBack, .createNew])
    }
    
    func test_persistenceError_consistentRecoveryActions() {
        let gameError = GameError.persistenceError("Test error")
        
        let contexts: [ConwayGameUserError.ErrorContext] = [
            .boardLoading, .boardCreation, .gameSimulation, .dataPersistence, .boardList
        ]
        
        for context in contexts {
            let userError = gameError.userFriendly(context: context)
            XCTAssertEqual(userError.recoveryActions, [.retry, .continueWithoutSaving])
        }
    }
    
    // MARK: - LocalizedError Conformance Tests
    
    func test_localizedErrorConformance() {
        let gameError = GameError.boardNotFound(UUID())
        let userError = gameError.userFriendly()
        
        XCTAssertEqual(userError.errorDescription, userError.userFriendlyMessage)
        XCTAssertEqual(userError.failureReason, userError.userFriendlyTitle)
        XCTAssertEqual(userError.recoverySuggestionString, userError.recoverySuggestion)
    }
    
    // MARK: - Empty Message Handling Tests
    
    func test_persistenceError_emptyMessage_providesDefault() {
        let gameError = GameError.persistenceError("")
        let userError = gameError.userFriendly()
        
        XCTAssertTrue(userError.userFriendlyMessage.contains("try again or restart"))
    }
    
    func test_computationError_emptyMessage_providesDefault() {
        let gameError = GameError.computationError("")
        let userError = gameError.userFriendly()
        
        XCTAssertTrue(userError.userFriendlyMessage.contains("unexpected pattern"))
    }
}

// MARK: - ErrorRecoveryAction Tests

final class ErrorRecoveryActionTests: XCTestCase {
    
    func test_actionTitles_areUserFriendly() {
        XCTAssertEqual(ErrorRecoveryAction.retry.title, "Retry")
        XCTAssertEqual(ErrorRecoveryAction.cancel.title, "Cancel")
        XCTAssertEqual(ErrorRecoveryAction.goBack.title, "Go Back")
        XCTAssertEqual(ErrorRecoveryAction.createNew.title, "Create New Board")
        XCTAssertEqual(ErrorRecoveryAction.resetBoard.title, "Reset Board")
        XCTAssertEqual(ErrorRecoveryAction.goToBoardList.title, "Go to Board List")
        XCTAssertEqual(ErrorRecoveryAction.continueWithoutSaving.title, "Continue Without Saving")
        XCTAssertEqual(ErrorRecoveryAction.tryAgain.title, "Try Again")
        XCTAssertEqual(ErrorRecoveryAction.contactSupport.title, "Contact Support")
    }
    
    func test_destructiveActions_flaggedCorrectly() {
        XCTAssertTrue(ErrorRecoveryAction.resetBoard.isDestructive)
        XCTAssertTrue(ErrorRecoveryAction.cancel.isDestructive)
        
        XCTAssertFalse(ErrorRecoveryAction.retry.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.goBack.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.createNew.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.goToBoardList.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.continueWithoutSaving.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.tryAgain.isDestructive)
        XCTAssertFalse(ErrorRecoveryAction.contactSupport.isDestructive)
    }
    
    func test_actionEquality() {
        XCTAssertEqual(ErrorRecoveryAction.retry, ErrorRecoveryAction.retry)
        XCTAssertNotEqual(ErrorRecoveryAction.retry, ErrorRecoveryAction.cancel)
    }
}

// MARK: - Error Context Tests

final class ErrorContextTests: XCTestCase {
    
    func test_allErrorTypes_haveContextSpecificBehavior() {
        let boardId = UUID()
        let gameErrors: [GameError] = [
            .boardNotFound(boardId),
            .convergenceTimeout(maxIterations: 100),
            .generationLimitExceeded(500),
            .invalidBoardDimensions,
            .persistenceError("Test"),
            .computationError("Test")
        ]
        
        let contexts: [ConwayGameUserError.ErrorContext] = [
            .boardLoading, .boardCreation, .gameSimulation, .dataPersistence, .boardList
        ]
        
        for gameError in gameErrors {
            for context in contexts {
                let userError = gameError.userFriendly(context: context)
                
                // All errors should have user-friendly properties
                XCTAssertFalse(userError.userFriendlyTitle.isEmpty)
                XCTAssertFalse(userError.userFriendlyMessage.isEmpty)
                XCTAssertFalse(userError.recoveryActions.isEmpty)
                
                // All errors should have recovery suggestions
                XCTAssertNotNil(userError.recoverySuggestion)
                XCTAssertFalse(userError.recoverySuggestion!.isEmpty)
            }
        }
    }
    
    func test_errorMessages_doNotContainTechnicalDetails() {
        let gameError = GameError.boardNotFound(UUID())
        let userError = gameError.userFriendly()
        
        // Should not contain UUIDs or technical identifiers
        XCTAssertFalse(userError.userFriendlyMessage.contains("UUID"))
        XCTAssertFalse(userError.userFriendlyMessage.contains("-"))
        XCTAssertFalse(userError.userFriendlyTitle.contains("UUID"))
    }
    
    func test_errorMessages_provideActionableGuidance() {
        let gameError = GameError.convergenceTimeout(maxIterations: 1000)
        let userError = gameError.userFriendly()
        
        // Should provide specific guidance
        XCTAssertTrue(userError.recoverySuggestion!.contains("smaller board") || 
                      userError.recoverySuggestion!.contains("simpler"))
    }
}