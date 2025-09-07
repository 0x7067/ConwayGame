import SwiftUI

struct GameControlsView: View {
    let isPlaying: Bool
    let onStep: () -> Void
    let onTogglePlay: () -> Void
    let onJump: (Int) -> Void
    let onFinal: (Int) -> Void
    @State private var genInput: String = "10"
    @State private var maxIterInput: String = "500"

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Button(action: onStep) { Label("Step", systemImage: "arrow.right.circle") }
                Button(action: onTogglePlay) {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.circle" : "play.circle")
                }
            }
            HStack {
                TextField("Gen", text: $genInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 80)
                Button("Jump") { if let g = Int(genInput) { onJump(g) } }
                Spacer()
                TextField("Max iters", text: $maxIterInput)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
                Button("Final") { if let m = Int(maxIterInput) { onFinal(m) } }
            }
        }
        .padding(.horizontal)
    }
}

