import SwiftUI

struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "New Board"
    @State private var width: Int = 20
    @State private var height: Int = 20
    @State private var cells: CellsGrid = Array(repeating: Array(repeating: false, count: 20), count: 20)
    @State private var errorMessage: String?
    // Navigation to PatternPicker is handled by NavigationLink (no sheet)

    let gameService: GameService
    var onCreated: ((UUID) -> Void)? = nil

    private func resizeGrid() {
        cells = Array(repeating: Array(repeating: false, count: width), count: height)
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
                    .frame(minHeight: 200)
            }
            Section {
                Button("Create") {
                    Task {
                        let result = await gameService.createBoard(cells, name: name)
                        switch result {
                        case .success(let id):
                            onCreated?(id)
                            dismiss()
                        case .failure(let e): errorMessage = e.localizedDescription
                        }
                    }
                }
            }
        }
        .navigationTitle("Create Board")
        .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
            Button("OK") { errorMessage = nil }
        } message: { msg in Text(msg) }
        .onChange(of: width) { _ in resizeGrid() }
        .onChange(of: height) { _ in resizeGrid() }
    }
}

private struct EditableGrid: View {
    @Binding var cells: CellsGrid
    var body: some View {
        GeometryReader { geo in
            let h = cells.count
            let w = h > 0 ? cells[0].count : 0
            let cellW = geo.size.width / CGFloat(max(1, w))
            let cellH = cellW
            ZStack(alignment: .topLeading) {
                // Live cells
                Canvas { ctx, _ in
                    for y in 0..<h {
                        for x in 0..<w where cells[y][x] {
                            let rect = CGRect(x: CGFloat(x) * cellW, y: CGFloat(y) * cellH, width: cellW, height: cellH)
                            ctx.fill(Path(rect), with: .color(.accentColor))
                        }
                    }
                }
                // Tap overlay grid
                ForEach(0..<h, id: \.self) { y in
                    ForEach(0..<w, id: \.self) { x in
                        Rectangle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                            .background((cells[y][x] ? Color.accentColor : Color.clear).opacity(0.001))
                            .frame(width: cellW, height: cellH)
                            .position(x: CGFloat(x) * cellW + cellW/2, y: CGFloat(y) * cellH + cellH/2)
                            .contentShape(Rectangle())
                            .onTapGesture { cells[y][x].toggle() }
                    }
                }
            }
            .frame(height: CGFloat(h) * cellH)
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
