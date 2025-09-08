import SwiftUI

struct CopyBoardData {
    let name: String
    let cells: CellsGrid
}

struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var name: String = "New Board"
    @State private var width: Int = DesignTokens.Grid.defaultBoardSize
    @State private var height: Int = DesignTokens.Grid.defaultBoardSize
    @State private var cells: CellsGrid = Array(repeating: Array(repeating: false, count: DesignTokens.Grid.defaultBoardSize), count: DesignTokens.Grid.defaultBoardSize)
    @State private var errorMessage: String?
    // Navigation to PatternPicker is handled by NavigationLink (no sheet)

    let gameService: GameService
    let repository: BoardRepository
    var copyFromBoard: CopyBoardData? = nil
    var onCreated: ((UUID) -> Void)? = nil

    private func resizeGrid() {
        let oldCells = cells
        let oldHeight = oldCells.count
        let oldWidth = oldHeight > 0 ? oldCells[0].count : 0
        
        // Create new grid with desired dimensions
        var newCells = Array(repeating: Array(repeating: false, count: width), count: height)
        
        // Copy existing cells to the new grid, preserving their positions
        for y in 0..<min(height, oldHeight) {
            for x in 0..<min(width, oldWidth) {
                newCells[y][x] = oldCells[y][x]
            }
        }
        
        cells = newCells
    }
    
    private func setupDefaults() {
        let defaultSize = themeManager.defaultBoardSize
        width = defaultSize
        height = defaultSize
        cells = Array(repeating: Array(repeating: false, count: defaultSize), count: defaultSize)
    }
    
    private func setupCopyData() {
        if let copyData = copyFromBoard {
            name = copyData.name + " COPY"
            height = copyData.cells.count
            width = copyData.cells.first?.count ?? 20
            cells = copyData.cells
        }
    }

    private func applyPattern(_ pattern: PredefinedPattern) {
        var grid = Array(repeating: Array(repeating: false, count: width), count: height)
        let pts = pattern.offsets
        guard !pts.isEmpty else { 
            cells = grid
            return 
        }
        
        let bounds = calculatePatternBounds(pts)
        let startPosition = calculateCenteredPosition(bounds)
        
        for (x, y) in pts {
            let gridX = x + startPosition.x
            let gridY = y + startPosition.y
            if isValidPosition(x: gridX, y: gridY) {
                grid[gridY][gridX] = true
            }
        }
        cells = grid
    }
    
    private func calculatePatternBounds(_ points: [(Int, Int)]) -> (minX: Int, maxX: Int, minY: Int, maxY: Int, width: Int, height: Int) {
        let minX = points.map { $0.0 }.min() ?? 0
        let maxX = points.map { $0.0 }.max() ?? 0
        let minY = points.map { $0.1 }.min() ?? 0
        let maxY = points.map { $0.1 }.max() ?? 0
        let width = maxX - minX + 1
        let height = maxY - minY + 1
        return (minX, maxX, minY, maxY, width, height)
    }
    
    private func calculateCenteredPosition(_ bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int, width: Int, height: Int)) -> (x: Int, y: Int) {
        let startX = max(0, (width - bounds.width) / 2) - bounds.minX
        let startY = max(0, (height - bounds.height) / 2) - bounds.minY
        return (startX, startY)
    }
    
    private func isValidPosition(x: Int, y: Int) -> Bool {
        x >= 0 && x < width && y >= 0 && y < height
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                Stepper(value: $width, in: DesignTokens.Grid.minBoardSize...DesignTokens.Grid.maxBoardSize, step: 1) {
                    HStack { Text("Width"); Spacer(); Text("\(width)") }
                }
                Stepper(value: $height, in: DesignTokens.Grid.minBoardSize...DesignTokens.Grid.maxBoardSize, step: 1) {
                    HStack { Text("Height"); Spacer(); Text("\(height)") }
                }
                Button("Clear Cells") {
                    cells = Array(repeating: Array(repeating: false, count: width), count: height)
                }
                Button("Randomize Cells") {
                    for y in 0..<height { for x in 0..<width { cells[y][x] = Bool.random() } }
                }
                NavigationLink(destination: PatternPickerView(onSelect: { applyPattern($0); name = $0.displayName })) {
                    Text("Choose Pattern…")
                }
            }
            Section(header: Text("Pattern")) {
                EditableGrid(cells: $cells)
            }
            Section {
                Button("Create") {
                    Task {
                        let id = await gameService.createBoard(cells)
                        // Update name if different
                        if name != "Board-\(id.uuidString.prefix(8))" {
                            try? await repository.rename(id: id, newName: name)
                        }
                        onCreated?(id)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("Create Board")
        .errorAlert(errorMessage: $errorMessage)
        .onChange(of: width) { resizeGrid() }
        .onChange(of: height) { resizeGrid() }
        .onAppear { 
            if copyFromBoard == nil {
                setupDefaults()
            }
            setupCopyData() 
        }
    }
}

private struct EditableGrid: View {
    @Binding var cells: CellsGrid
    
    var body: some View {
        let h = cells.count
        let w = h > 0 ? cells[0].count : 0
        
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: w), spacing: 1) {
            ForEach(0..<(h * w), id: \.self) { index in
                let x = index % w
                let y = index / w
                Rectangle()
                    .fill(cells[y][x] ? Color.accentColor : Color(.systemGray6))
                    .border(Color.secondary.opacity(DesignTokens.Opacity.disabled), width: 0.5)
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        cells[y][x].toggle()
                    }
            }
        }
    }
}

// Common Game of Life patterns as relative offsets
