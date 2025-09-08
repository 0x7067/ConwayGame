import SwiftUI

struct CopyBoardData {
    let name: String
    let cells: CellsGrid
}

struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "New Board"
    @State private var width: Int = 15
    @State private var height: Int = 15
    @State private var cells: CellsGrid = Array(repeating: Array(repeating: false, count: 15), count: 15)
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
        guard !pts.isEmpty else { cells = grid; return }
        let minX = pts.map { $0.0 }.min() ?? 0
        let maxX = pts.map { $0.0 }.max() ?? 0
        let minY = pts.map { $0.1 }.min() ?? 0
        let maxY = pts.map { $0.1 }.max() ?? 0
        let patternW = maxX - minX + 1
        let patternH = maxY - minY + 1
        let startX = max(0, (width - patternW) / 2) - minX
        let startY = max(0, (height - patternH) / 2) - minY
        for (x, y) in pts {
            let gx = x + startX
            let gy = y + startY
            if gx >= 0 && gx < width && gy >= 0 && gy < height {
                grid[gy][gx] = true
            }
        }
        cells = grid
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                Stepper(value: $width, in: 5...UIConstants.maxBoardDimension, step: 1) {
                    HStack { Text("Width"); Spacer(); Text("\(width)") }
                }
                Stepper(value: $height, in: 5...UIConstants.maxBoardDimension, step: 1) {
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
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in Text(msg) }
        .onChange(of: width) { resizeGrid() }
        .onChange(of: height) { resizeGrid() }
        .onAppear { setupCopyData() }
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
                    .border(Color.secondary.opacity(0.4), width: 0.5)
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        cells[y][x].toggle()
                        print("Toggled cell (\(x), \(y)) to \(cells[y][x])") // Debug print
                    }
            }
        }
    }
}

// Common Game of Life patterns as relative offsets
enum PredefinedPattern: String, CaseIterable, Identifiable {
    case block
    case beehive
    case blinker
    case toad
    case beacon
    case glider

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .block: return "Block"
        case .beehive: return "Beehive"
        case .blinker: return "Blinker"
        case .toad: return "Toad"
        case .beacon: return "Beacon"
        case .glider: return "Glider"
        }
    }

    var offsets: [(Int, Int)] {
        switch self {
        case .block:
            return [(0,0),(1,0),(0,1),(1,1)]
        case .beehive:
            return [(1,0),(2,0),(0,1),(3,1),(1,2),(2,2)]
        case .blinker:
            return [(0,0),(1,0),(2,0)]
        case .toad:
            return [(1,0),(2,0),(3,0),(0,1),(1,1),(2,1)]
        case .beacon:
            return [(0,0),(1,0),(0,1),(1,1),(2,2),(3,2),(2,3),(3,3)]
        case .glider:
            return [(1,0),(2,1),(0,2),(1,2),(2,2)]
        }
    }
}
