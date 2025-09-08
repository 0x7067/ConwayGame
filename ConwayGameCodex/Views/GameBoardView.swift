import SwiftUI

struct GameBoardView: View {
    @StateObject private var vm: GameViewModel
    @State private var showGrid: Bool = true
    @State private var showingCopySheet = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var navigationPath: NavigationPath

    let gameService: GameService
    let repository: BoardRepository

    init(gameService: GameService, repository: BoardRepository, boardId: UUID, navigationPath: Binding<NavigationPath>, themeManager: ThemeManager) {
        self.gameService = gameService
        self.repository = repository
        _vm = StateObject(wrappedValue: GameViewModel(service: gameService, repository: repository, boardId: boardId, themeManager: themeManager))
        _navigationPath = navigationPath
    }
    
    private func dismissToRoot() {
        // Clear the navigation path to go back to root (BoardListView)
        navigationPath.removeLast(navigationPath.count)
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
                playSpeed: $vm.playSpeed,
                onStep: { Task { await vm.step() } },
                onTogglePlay: { vm.isPlaying ? vm.pause() : vm.play() },
                onJump: { gen in Task { await vm.jump(to: gen) } },
                onFinal: { maxIters in Task { await vm.finalState(maxIterations: maxIters) } },
                onReset: { Task { await vm.reset() } }
            )
            .padding(.bottom)
        }
        .navigationTitle("Game")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismissToRoot()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Boards")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { showingCopySheet = true }) {
                        Image(systemName: "doc.on.doc")
                    }
                    Toggle(isOn: $showGrid) { 
                        Image(systemName: showGrid ? "square.grid.3x3" : "square") 
                    }
                }
            }
        }
        .onDisappear { vm.pause() }
        .task { await vm.loadCurrent() }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil), presenting: vm.errorMessage) { _ in
            Button("OK") { vm.errorMessage = nil }
        } message: { msg in Text(msg) }
        .sheet(isPresented: $showingCopySheet) {
            if let state = vm.state {
                NavigationView {
                    CreateBoardView(
                        gameService: gameService,
                        repository: repository,
                        copyFromBoard: CopyBoardData(
                            name: vm.boardName,
                            cells: state.cells
                        )
                    ) { newBoardIdFromCreation in
                        showingCopySheet = false
                        navigationPath.append(newBoardIdFromCreation)
                    }
                }
            }
        }
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
                    ctx.stroke(path, with: .color(.secondary.opacity(DesignTokens.Opacity.light)), lineWidth: 0.5)
                }
            }
            .frame(height: CGFloat(h) * cellH)
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    return NavigationStack(path: $path) {
        GameBoardView(
            gameService: ServiceContainer.shared.gameService, 
            repository: ServiceContainer.shared.boardRepository, 
            boardId: UUID(),
            navigationPath: $path,
            themeManager: ThemeManager()
        )
    }
}
