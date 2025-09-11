import SwiftUI
import ConwayGameEngine

struct GameControlsView: View {
    let isPlaying: Bool
    var isLocked: Bool = false
    var gameState: GameState? = nil
    @Binding var playSpeed: PlaySpeed
    let onStep: () -> Void
    let onTogglePlay: () -> Void
    let onJump: (Int) -> Void
    let onFinal: (Int) -> Void
    var onReset: (() -> Void)? = nil
    @State private var genInput: String = "10"
    @State private var maxIterInput: String = "500"

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            // Primary Controls - Prominent and centered
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Play controls with better visual hierarchy
                HStack(spacing: DesignTokens.Spacing.xxl) {
                    // Step button
                    Button(action: onStep) {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.frame")
                                .font(.system(size: DesignTokens.FontSize.h2))
                                .foregroundColor(isLocked ? .gray : .accentColor)
                            Text("Step")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 60)
                    }
                    .accessibilityIdentifier("step")
                    .disabled(isLocked)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Play/Pause - Central and larger
                    Button(action: onTogglePlay) {
                        ZStack {
                            Circle()
                                .fill(isLocked ? Color.gray.opacity(DesignTokens.Opacity.disabled) : Color.accentColor)
                                .frame(width: DesignTokens.IconSize.hero, height: DesignTokens.IconSize.hero)
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: DesignTokens.FontSize.h2))
                                .foregroundColor(.white)
                                .offset(x: isPlaying ? 0 : 2)
                        }
                    }
                    .accessibilityIdentifier("play")
                    .accessibilityLabel(isPlaying ? "Pause" : "Play")
                    .disabled(isLocked)
                    .buttonStyle(PlainButtonStyle())
                    
                    // Reset button
                    if let onReset {
                        Button(action: onReset) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: DesignTokens.FontSize.h2))
                                    .foregroundColor(.accentColor)
                                Text("Reset")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 60)
                        }
                        .accessibilityLabel("Reset")
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Speed control - Elegant capsule style
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Picker("Speed", selection: $playSpeed) {
                        ForEach(PlaySpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 180)
                    .disabled(isLocked)
                }
            }
            .padding(.vertical, DesignTokens.Padding.md)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                    .fill(Color(.systemGray6))
            )
            
            // Secondary Controls - Smaller and subdued
            HStack(spacing: 20) {
                // Jump to generation
                HStack(spacing: DesignTokens.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("JUMP TO")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("10", text: $genInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            Button(action: { if let g = Int(genInput) { onJump(min(g, UIConstants.maxJumpGeneration)) } }) {
                                Text("Go")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, DesignTokens.Padding.md)
                                    .padding(.vertical, 6)
                                    .background(isLocked ? Color.gray : Color.accentColor)
                                    .cornerRadius(6)
                            }
                            .disabled(isLocked)
                        }
                    }
                }
                
                Spacer()
                
                // Find final state
                HStack(spacing: DesignTokens.Spacing.sm) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("FIND FINAL")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("\(UIConstants.maxGenerationLimit)", text: $maxIterInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                            Button(action: { if let m = Int(maxIterInput) { onFinal(min(m, UIConstants.maxGenerationLimit)) } }) {
                                Text("Find")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, DesignTokens.Padding.md)
                                    .padding(.vertical, 6)
                                    .background(isLocked ? Color.gray : Color.accentColor)
                                    .cornerRadius(6)
                            }
                            .disabled(isLocked)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            
            // Status message
            if isLocked {
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    VStack(alignment: .leading, spacing: 2) {
                        if let state = gameState, let convergenceType = state.convergenceType {
                            Text("Pattern \(convergenceType.displayName.lowercased()) at generation \(state.generation).")
                                .font(.caption)
                        } else {
                            Text("Final state reached.")
                                .font(.caption)
                        }
                        Text("Reset to continue.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.orange)
                .padding(.horizontal, DesignTokens.Padding.lg)
                .padding(.vertical, DesignTokens.Padding.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                        .fill(Color.orange.opacity(DesignTokens.Opacity.light))
                )
            }
        }
        .padding(.horizontal)
    }
}
