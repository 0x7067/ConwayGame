import SwiftUI
import ConwayGameEngine

// MARK: - Enhanced Error Alert System

struct SmartErrorAlertModifier: ViewModifier {
    @Binding var error: UserFriendlyError?
    let onRecoveryAction: (ErrorRecoveryAction) -> Void
    
    func body(content: Content) -> some View {
        content
            .alert(
                error?.userFriendlyTitle ?? "Error",
                isPresented: .init(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { presentedError in
                // Recovery action buttons
                ForEach(presentedError.recoveryActions.indices, id: \.self) { index in
                    let action = presentedError.recoveryActions[index]
                    Button(action.title, role: action.isDestructive ? .destructive : .none) {
                        onRecoveryAction(action)
                        error = nil
                    }
                }
                
                // Always include a cancel/dismiss option if not already present
                if !presentedError.recoveryActions.contains(.cancel) {
                    Button("OK") { error = nil }
                }
            } message: { presentedError in
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentedError.userFriendlyMessage)
                    
                    if let suggestion = presentedError.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
    }
}

// MARK: - Legacy Error Alert (for backward compatibility)

struct ErrorAlertModifier: ViewModifier {
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { msg in
                Text(msg)
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Enhanced error alert with user-friendly messages and recovery actions
    func smartErrorAlert(
        error: Binding<UserFriendlyError?>,
        onRecoveryAction: @escaping (ErrorRecoveryAction) -> Void = { _ in }
    ) -> some View {
        modifier(SmartErrorAlertModifier(error: error, onRecoveryAction: onRecoveryAction))
    }
    
    /// Legacy error alert for backward compatibility
    func errorAlert(errorMessage: Binding<String?>) -> some View {
        modifier(ErrorAlertModifier(errorMessage: errorMessage))
    }
    
    /// Convenience method for GameError with context
    func gameErrorAlert(
        gameError: Binding<GameError?>,
        context: ConwayGameUserError.ErrorContext = .gameSimulation,
        onRecoveryAction: @escaping (ErrorRecoveryAction) -> Void = { _ in }
    ) -> some View {
        let userFriendlyError = Binding<UserFriendlyError?>(
            get: { gameError.wrappedValue?.userFriendly(context: context) },
            set: { newValue in
                if newValue == nil {
                    gameError.wrappedValue = nil
                }
            }
        )
        return smartErrorAlert(error: userFriendlyError, onRecoveryAction: onRecoveryAction)
    }
}