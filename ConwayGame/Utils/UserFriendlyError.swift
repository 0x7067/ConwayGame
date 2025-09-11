import Foundation
import ConwayGameEngine

/// Protocol for errors that provide user-friendly messages and recovery actions
protocol UserFriendlyError: LocalizedError {
    /// User-friendly title for the error
    var userFriendlyTitle: String { get }
    
    /// User-friendly description that explains what went wrong
    var userFriendlyMessage: String { get }
    
    /// Optional recovery suggestions for the user
    var recoverySuggestion: String? { get }
    
    /// Available recovery actions
    var recoveryActions: [ErrorRecoveryAction] { get }
}

/// Recovery actions that users can take when encountering errors
enum ErrorRecoveryAction: Equatable {
    case retry
    case cancel
    case goBack
    case createNew
    case resetBoard
    case goToBoardList
    case continueWithoutSaving
    case tryAgain
    case contactSupport
    
    var title: String {
        switch self {
        case .retry:
            return "Retry"
        case .cancel:
            return "Cancel"
        case .goBack:
            return "Go Back"
        case .createNew:
            return "Create New Board"
        case .resetBoard:
            return "Reset Board"
        case .goToBoardList:
            return "Go to Board List"
        case .continueWithoutSaving:
            return "Continue Without Saving"
        case .tryAgain:
            return "Try Again"
        case .contactSupport:
            return "Contact Support"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .resetBoard, .cancel:
            return true
        default:
            return false
        }
    }
}

/// Wrapper for GameError to provide user-friendly messages and recovery actions
struct ConwayGameUserError: UserFriendlyError {
    let gameError: GameError
    let context: ErrorContext
    
    enum ErrorContext {
        case boardLoading
        case boardCreation
        case gameSimulation
        case dataPersistence
        case boardList
    }
    
    init(_ gameError: GameError, context: ErrorContext = .gameSimulation) {
        self.gameError = gameError
        self.context = context
    }
    
    var userFriendlyTitle: String {
        switch gameError {
        case .boardNotFound:
            return "Board Not Found"
        case .convergenceTimeout:
            return "Simulation Taking Too Long"
        case .generationLimitExceeded:
            return "Simulation Limit Reached"
        case .invalidBoardDimensions:
            return "Invalid Board Setup"
        case .persistenceError:
            return "Saving Problem"
        case .computationError:
            return "Simulation Error"
        }
    }
    
    var userFriendlyMessage: String {
        switch gameError {
        case .boardNotFound:
            return "The board you're looking for couldn't be found. It may have been deleted or moved."
        case .convergenceTimeout(let maxIterations):
            return "The simulation is taking longer than expected (\(maxIterations) steps). This often happens with complex patterns that don't stabilize quickly."
        case .generationLimitExceeded(let generations):
            return "The simulation reached \(generations) generations without settling into a stable pattern. The cells are still actively changing."
        case .invalidBoardDimensions:
            return "The board setup has invalid dimensions or contains irregular cell arrangements that can't be simulated."
        case .persistenceError(let message):
            return "Unable to save your progress. \(message.isEmpty ? "Please try again or restart the app if the problem persists." : message)"
        case .computationError(let message):
            return "Something went wrong during the simulation. \(message.isEmpty ? "This might be due to an unexpected pattern or board state." : message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch gameError {
        case .boardNotFound:
            return "Try creating a new board or selecting a different one from your board list."
        case .convergenceTimeout:
            return "Consider using a smaller board size or simpler initial pattern for faster results."
        case .generationLimitExceeded:
            return "You can continue manually stepping through generations or reset the board to try a different pattern."
        case .invalidBoardDimensions:
            return "Create a new board with standard dimensions between 10x10 and 100x100 cells."
        case .persistenceError:
            return "Check if you have enough storage space and try saving again."
        case .computationError:
            return "Try resetting the board to its initial state or creating a new board with a simpler pattern."
        }
    }
    
    var recoveryActions: [ErrorRecoveryAction] {
        switch (gameError, context) {
        case (.boardNotFound, .boardLoading):
            return [.goToBoardList, .createNew]
        case (.boardNotFound, _):
            return [.goBack, .createNew]
        case (.convergenceTimeout, _):
            return [.cancel, .tryAgain]
        case (.generationLimitExceeded, _):
            return [.resetBoard, .cancel]
        case (.invalidBoardDimensions, _):
            return [.createNew, .goBack]
        case (.persistenceError, _):
            return [.retry, .continueWithoutSaving]
        case (.computationError, _):
            return [.resetBoard, .tryAgain]
        }
    }
    
    // LocalizedError conformance
    var errorDescription: String? {
        return userFriendlyMessage
    }
    
    var failureReason: String? {
        return userFriendlyTitle
    }
    
    var recoverySuggestionString: String? {
        return recoverySuggestion
    }
}

/// Extension to wrap GameError with user-friendly context
extension GameError {
    func userFriendly(context: ConwayGameUserError.ErrorContext = .gameSimulation) -> ConwayGameUserError {
        return ConwayGameUserError(self, context: context)
    }
}