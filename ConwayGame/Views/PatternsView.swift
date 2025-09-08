import SwiftUI

struct PatternsView: View {
    struct PatternInfo: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let patterns: [PredefinedPattern]
        let boardSize: Int
    }

    private let patternGroups: [PatternInfo] = [
        PatternInfo(title: "Still lifes", description: "Stable shapes that do not change from one generation to the next.", patterns: [.block, .beehive], boardSize: 8),
        PatternInfo(title: "Oscillators", description: "Patterns that repeat after a finite number of steps.", patterns: [.blinker, .toad, .beacon], boardSize: 8),
        PatternInfo(title: "Spaceships", description: "Patterns that move across the board while maintaining their shape.", patterns: [.glider], boardSize: 8),
    ]

    var body: some View {
        List {
            Text("Common Patterns").font(.headline)
            
            ForEach(patternGroups) { group in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(group.title).font(.headline)
                    Text(group.description).font(.subheadline).foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.lg) {
                            ForEach(group.patterns, id: \.id) { pattern in
                                VStack(spacing: DesignTokens.Spacing.sm) {
                                    AnimatedPatternView(pattern: pattern, boardSize: group.boardSize)
                                        .frame(width: 80, height: 80)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(DesignTokens.CornerRadius.sm)
                                    Text(pattern.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("pattern-\(pattern.rawValue)")
                                }
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
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

// Animated pattern display that reuses existing components
private struct AnimatedPatternView: View {
    let pattern: PredefinedPattern
    let boardSize: Int
    
    @State private var currentState: CellsGrid
    @State private var generation = 0
    private let engine = ConwayGameEngine()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    init(pattern: PredefinedPattern, boardSize: Int) {
        self.pattern = pattern
        self.boardSize = boardSize
        
        // Initialize the pattern on the board
        var grid = Array(repeating: Array(repeating: false, count: boardSize), count: boardSize)
        let offsets = pattern.offsets
        let centerX = boardSize / 2
        let centerY = boardSize / 2
        
        for (x, y) in offsets {
            let gridX = centerX + x - 1
            let gridY = centerY + y - 1
            if gridX >= 0 && gridX < boardSize && gridY >= 0 && gridY < boardSize {
                grid[gridY][gridX] = true
            }
        }
        
        self._currentState = State(initialValue: grid)
    }
    
    var body: some View {
        // Reuse the BoardGrid component from GameBoardView
        PatternBoardGrid(cells: currentState, showGrid: false)
            .onReceive(timer) { _ in
                let nextState = engine.computeNextState(currentState)
                
                // For still lifes, don't animate
                if pattern == .block || pattern == .beehive {
                    return
                }
                
                // For oscillators and gliders, reset after a cycle
                generation += 1
                let maxCycle = getPatternCycle()
                
                if generation >= maxCycle {
                    // Reset to initial state
                    resetToInitialState()
                } else {
                    currentState = nextState
                }
            }
    }
    
    private func getPatternCycle() -> Int {
        switch pattern {
        case .blinker, .toad, .beacon:
            return 2 // Period 2 oscillators
        case .glider:
            return 4 // Glider cycle
        default:
            return 1
        }
    }
    
    private func resetToInitialState() {
        generation = 0
        var grid = Array(repeating: Array(repeating: false, count: boardSize), count: boardSize)
        let offsets = pattern.offsets
        let centerX = boardSize / 2
        let centerY = boardSize / 2
        
        for (x, y) in offsets {
            let gridX = centerX + x - 1
            let gridY = centerY + y - 1
            if gridX >= 0 && gridX < boardSize && gridY >= 0 && gridY < boardSize {
                grid[gridY][gridX] = true
            }
        }
        
        currentState = grid
    }
}

// Simplified BoardGrid component for patterns (extracted from GameBoardView)
private struct PatternBoardGrid: View {
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
    PatternsView()
}
