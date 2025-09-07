import SwiftUI

struct GameControlsView: View {
    let isPlaying: Bool
    var isLocked: Bool = false
    @Binding var playSpeed: PlaySpeed
    let onStep: () -> Void
    let onTogglePlay: () -> Void
    let onJump: (Int) -> Void
    let onFinal: (Int) -> Void
    var onReset: (() -> Void)? = nil
    @State private var genInput: String = "10"
    @State private var maxIterInput: String = "500"

    var body: some View {
        VStack(spacing: 20) {
            // Primary Controls - Prominent and centered
            VStack(spacing: 16) {
                // Play controls with better visual hierarchy
                HStack(spacing: 24) {
                    // Step button
                    Button(action: onStep) {
                        VStack(spacing: 4) {
                            Image(systemName: "forward.frame")
                                .font(.system(size: 24))
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
                                .fill(isLocked ? Color.gray.opacity(0.3) : Color.accentColor)
                                .frame(width: 64, height: 64)
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
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
                                    .font(.system(size: 24))
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
                VStack(spacing: 8) {
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
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            
            // Secondary Controls - Smaller and subdued
            HStack(spacing: 20) {
                // Jump to generation
                HStack(spacing: 8) {
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
                                    .padding(.horizontal, 12)
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
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("FIND FINAL")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            TextField("500", text: $maxIterInput)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 70)
                                .multilineTextAlignment(.trailing)
                            Button(action: { if let m = Int(maxIterInput) { onFinal(min(m, UIConstants.maxFinalIterations)) } }) {
                                Text("Find")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
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
                    Text("Final state reached. Reset to continue.")
                        .font(.caption)
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )
            }
        }
        .padding(.horizontal)
    }
}
