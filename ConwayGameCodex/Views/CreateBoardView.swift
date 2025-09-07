import SwiftUI

struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = "New Board"
    @State private var width: Int = 20
    @State private var height: Int = 20
    @State private var cells: CellsGrid = Array(repeating: Array(repeating: false, count: 20), count: 20)
    @State private var errorMessage: String?

    let gameService: GameService

    private func resizeGrid() {
        cells = Array(repeating: Array(repeating: false, count: width), count: height)
    }

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                Stepper(value: $width, in: 5...100, step: 1, onEditingChanged: { _ in resizeGrid() }) {
                    HStack { Text("Width"); Spacer(); Text("\(width)") }
                }
                Stepper(value: $height, in: 5...100, step: 1, onEditingChanged: { _ in resizeGrid() }) {
                    HStack { Text("Height"); Spacer(); Text("\(height)") }
                }
                HStack {
                    Button("Clear") { cells = Array(repeating: Array(repeating: false, count: width), count: height) }
                    Spacer()
                    Button("Random") {
                        for y in 0..<height { for x in 0..<width { cells[y][x] = Bool.random() } }
                    }
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
                        case .success: dismiss()
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
        .onAppear { resizeGrid() }
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

