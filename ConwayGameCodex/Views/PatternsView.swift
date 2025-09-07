import SwiftUI

struct PatternsView: View {
    struct PatternInfo: Identifiable {
        let id = UUID()
        let title: String
        let description: String
    }

    private let patterns: [PatternInfo] = [
        PatternInfo(title: "Still lifes", description: "Stable shapes that do not change from one generation to the next. Examples: Block, Beehive."),
        PatternInfo(title: "Oscillators", description: "Patterns that repeat after a finite number of steps. Examples: Blinker (period 2), Toad (period 2), Beacon (period 2)."),
        PatternInfo(title: "Glider", description: "A small pattern that moves diagonally across the board, repeating every 4 generations while translating one cell."),
        PatternInfo(title: "Gosper Glider Gun", description: "A famous configuration that periodically emits gliders indefinitely. Requires a larger board to showcase."),
    ]

    var body: some View {
        List {
            Section(header: Text("Common Patterns")) {
                ForEach(patterns) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(p.title).font(.headline)
                        Text(p.description).font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            Section(header: Text("Try Them")) {
                Text("When creating a board, open the Patterns menu to auto-place these shapes centered on the grid.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Patterns")
    }
}

#Preview {
    PatternsView()
}

