import SwiftUI

struct BoardListView: View {
    @StateObject private var vm: BoardListViewModel
    @State private var createdId: UUID?

    init(gameService: GameService) {
        _vm = StateObject(wrappedValue: BoardListViewModel(service: gameService))
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(vm.boards, id: \.id) { board in
                    NavigationLink(destination: GameBoardView(gameService: ServiceContainer.shared.gameService, boardId: board.id)) {
                        HStack {
                            Text(board.name)
                            Spacer()
                            Text("\(board.width)x\(board.height)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    Task { for i in idx { await vm.delete(id: vm.boards[i].id) } }
                }
            }
            .navigationTitle("Boards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        NavigationLink(destination: CreateBoardView(gameService: ServiceContainer.shared.gameService)) {
                            Image(systemName: "square.grid.3x3.fill")
                        }
                        Button {
                            Task { await vm.createRandomBoard(name: "Random", width: 40, height: 30, density: 0.25) }
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            .task { await vm.load() }
            Text("Create a board to begin")
        }
    }
}

struct BoardListView_Previews: PreviewProvider {
    static var previews: some View {
        BoardListView(gameService: ServiceContainer.shared.gameService)
    }
}
