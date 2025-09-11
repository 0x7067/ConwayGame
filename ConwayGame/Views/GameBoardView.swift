import SwiftUI
import ConwayGameEngine
import FactoryKit

struct GameBoardView: View {
    @StateObject private var vm: GameViewModel
    @State private var showGrid: Bool = true
    @State private var showingCopySheet = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var navigationPath: NavigationPath
    @Injected(\.gameService) private var gameService: GameService
    @Injected(\.boardRepository) private var repository: BoardRepository

    init(boardId: UUID, navigationPath: Binding<NavigationPath>, themeManager: ThemeManager) {
        _vm = StateObject(wrappedValue: GameViewModel(boardId: boardId))
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
                    VStack(alignment: .leading, spacing: 2) {
                        if let convergenceType = state.convergenceType {
                            Text("Gen: \(state.generation) (\(convergenceType.displayName))")
                                .foregroundColor(.accentColor)
                        } else {
                            Text("Gen: \(state.generation)")
                        }
                        
                        if let convergedAt = state.convergedAt, convergedAt != state.generation {
                            Text("Final state found at gen \(convergedAt)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text("Pop: \(state.populationCount)")
                }.padding(.horizontal)
            } else {
                Text("Loading board…")
            }
            GameControlsView(
                isPlaying: vm.isPlaying,
                isLocked: vm.isFinalLocked,
                gameState: vm.state,
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
        .accessibilityIdentifier("game-board-view")
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
        .errorAlert(errorMessage: $vm.errorMessage)
        .alert("Generation Limit Reached", isPresented: $vm.showGenerationLimitAlert) {
            Button("OK") { vm.showGenerationLimitAlert = false }
        } message: {
            Text("Game didn't reach a final state after 500 generations. There are still living cells.")
        }
        .sheet(isPresented: $showingCopySheet) {
            if let state = vm.state {
                NavigationView {
                    CreateBoardView(
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
            boardId: UUID(),
            navigationPath: $path,
            themeManager: ThemeManager()
        )
    }
}
