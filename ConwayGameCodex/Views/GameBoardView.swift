import SwiftUI

struct GameBoardView: View {
    @StateObject private var vm: GameViewModel
    @State private var showGrid: Bool = true

    init(gameService: GameService, boardId: UUID) {
        _vm = StateObject(wrappedValue: GameViewModel(service: gameService, boardId: boardId))
    }

    var body: some View {
        VStack(spacing: 12) {
            if let state = vm.state {
                BoardGrid(cells: state.cells, showGrid: showGrid)
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal)
                HStack {
                    Text("Gen: \(state.generation)")
                    Spacer()
                    Text("Pop: \(state.populationCount)")
                }.padding(.horizontal)
            } else {
                Text("Loading board…")
            }
            GameControlsView(
                isPlaying: vm.isPlaying,
                isLocked: vm.isFinalLocked,
                onStep: { Task { await vm.step() } },
                onTogglePlay: { vm.isPlaying ? vm.pause() : vm.play() },
                onJump: { gen in Task { await vm.jump(to: gen) } },
                onFinal: { maxIters in Task { await vm.finalState(maxIterations: maxIters) } },
                onReset: { Task { await vm.reset() } }
            )
            .padding(.bottom)
        }
        .navigationTitle("Game")
        .toolbar { Toggle(isOn: $showGrid) { Image(systemName: showGrid ? "square.grid.3x3" : "square") } }
        .onDisappear { vm.pause() }
        .task { await vm.loadCurrent() }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
            Button("OK") { vm.errorMessage = nil }
        } message: { msg in Text(msg) }
    }
}

private struct BoardGrid: View {
    let cells: CellsGrid
    let showGrid: Bool
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
                if showGrid {
                    var path = Path()
                    // Vertical lines
                    for x in 0...w {
                        let px = CGFloat(x) * cellW
                        path.move(to: CGPoint(x: px, y: 0))
                        path.addLine(to: CGPoint(x: px, y: CGFloat(h) * cellH))
                    }
                    // Horizontal lines
                    for y in 0...h {
                        let py = CGFloat(y) * cellH
                        path.move(to: CGPoint(x: 0, y: py))
                        path.addLine(to: CGPoint(x: CGFloat(w) * cellW, y: py))
                    }
                    ctx.stroke(path, with: .color(.secondary.opacity(0.25)), lineWidth: 0.5)
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
