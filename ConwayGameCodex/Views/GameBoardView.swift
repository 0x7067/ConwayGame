import SwiftUI

struct GameBoardView: View {
    @StateObject private var vm: GameViewModel

    init(gameService: GameService, boardId: UUID) {
        _vm = StateObject(wrappedValue: GameViewModel(service: gameService, boardId: boardId))
    }

    var body: some View {
        VStack(spacing: 12) {
            if let state = vm.state {
                BoardGrid(cells: state.cells)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal)
                HStack {
                    Text("Gen: \(state.generation)")
                    Spacer()
                    Text("Pop: \(state.populationCount)")
                }.padding(.horizontal)
            } else {
                Text("No state yet. Tap Step.")
            }
            GameControlsView(
                isPlaying: vm.isPlaying,
                onStep: { Task { await vm.step() } },
                onTogglePlay: { vm.isPlaying ? vm.pause() : vm.play() },
                onJump: { gen in Task { await vm.jump(to: gen) } },
                onFinal: { maxIters in Task { await vm.finalState(maxIterations: maxIters) } }
            )
            .padding(.bottom)
        }
        .navigationTitle("Game")
        .onDisappear { vm.pause() }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
            Button("OK") { vm.errorMessage = nil }
        } message: { msg in Text(msg) }
    }
}

private struct BoardGrid: View {
    let cells: CellsGrid
    var body: some View {
        GeometryReader { geo in
            let h = cells.count
            let w = h > 0 ? cells[0].count : 0
            let cellW = geo.size.width / CGFloat(max(1, w))
            let cellH = geo.size.width / CGFloat(max(1, w)) // keep square
            Canvas { ctx, size in
                for y in 0..<h {
                    for x in 0..<w {
                        if cells[y][x] {
                            let rect = CGRect(x: CGFloat(x) * cellW, y: CGFloat(y) * cellH, width: cellW, height: cellH)
                            ctx.fill(Path(rect), with: .color(.accentColor))
                        }
                    }
                }
            }
            .frame(height: CGFloat(h) * cellH)
        }
    }
}

struct GameBoardView_Previews: PreviewProvider {
    static var previews: some View {
        let service = ServiceContainer.shared.gameService
        let grid = Array(repeating: Array(repeating: false, count: 10), count: 10)
        return GameBoardView(gameService: service, boardId: UUID())
    }
}
