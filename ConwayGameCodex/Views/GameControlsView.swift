import SwiftUI

struct GameControlsView: View {
    let isPlaying: Bool
    var isLocked: Bool = false
    let onStep: () -> Void
    let onTogglePlay: () -> Void
    let onJump: (Int) -> Void
    let onFinal: (Int) -> Void
    var onReset: (() -> Void)? = nil
    @State private var genInput: String = "10"
    @State private var maxIterInput: String = "500"

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Button(action: onStep) { Label("Step", systemImage: "arrow.right.circle") }
                    .accessibilityIdentifier("step")
                    .disabled(isLocked)
                Button(action: onTogglePlay) {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle" : "play.circle")
                }
                .accessibilityIdentifier("play")
                .disabled(isLocked)
                if let onReset { Button(action: onReset) { Label("Reset", systemImage: "arrow.counterclockwise") } }
            }
            HStack {
                TextField("Gen", text: $genInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                Button("Jump") { if let g = Int(genInput) { onJump(min(g, UIConstants.maxJumpGeneration)) } }
                    .disabled(isLocked)
                Spacer()
                TextField("Max iters", text: $maxIterInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                Button("Final") { if let m = Int(maxIterInput) { onFinal(min(m, UIConstants.maxFinalIterations)) } }
                    .disabled(isLocked)
            }
            if isLocked {
                Text("Final state locked. Reset to start over.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
