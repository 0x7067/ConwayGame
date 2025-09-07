import SwiftUI

struct BoardListView: View {
    @StateObject private var vm: BoardListViewModel
    @State private var createdId: UUID?
    @State private var navigateToCreated: Bool = false
    @State private var renamingBoard: Board?
    @State private var newName: String = ""
    @State private var showingCreate: Bool = false

    init(gameService: GameService) {
        _vm = StateObject(wrappedValue: BoardListViewModel(service: gameService))
    }

    var body: some View {
        ZStack {
            // Hidden link for programmatic navigation to newly created board
            NavigationLink(isActive: $navigateToCreated) {
                if let id = createdId {
                    GameBoardView(gameService: ServiceContainer.shared.gameService, boardId: id)
                }
            } label: { EmptyView() }

            List {
                ForEach(vm.boards, id: \.id) { board in
                    NavigationLink(destination: GameBoardView(gameService: ServiceContainer.shared.gameService, boardId: board.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(board.name)
                                Spacer()
                                Text("\(board.width)x\(board.height)")
                                    .foregroundColor(.secondary)
                            }
                            Text("Created: \(board.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Rename") { renamingBoard = board; newName = board.name }
                    }
                }
                .onDelete { idx in
                    Task { for i in idx { await vm.delete(id: vm.boards[i].id) } }
                }
            }
        }
        .navigationTitle("Boards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showingCreate = true
                    } label: { Image(systemName: "square.grid.3x3.fill") }
                    Button {
                        Task { await vm.createRandomBoard(name: "Random", width: 40, height: 30, density: 0.25) }
                    } label: { Image(systemName: "plus") }
                }
            }
        }
        .task { await vm.load() }
        .fullScreenCover(isPresented: $showingCreate) {
            CreateBoardRoot(gameService: ServiceContainer.shared.gameService, onCreated: { id in
                createdId = id
                navigateToCreated = true
                Task { await vm.load() }
            })
        }
        .sheet(item: $renamingBoard) { b in
            NavigationStack {
                Form {
                    Section(header: Text("Rename Board")) {
                        TextField("Name", text: $newName)
                    }
                }
                .navigationTitle("Rename")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renamingBoard = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let nameTrimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !nameTrimmed.isEmpty else { renamingBoard = nil; return }
                            Task {
                                _ = await ServiceContainer.shared.gameService.renameBoard(id: b.id, newName: nameTrimmed)
                                renamingBoard = nil
                                await vm.load()
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BoardListView_Previews: PreviewProvider {
    static var previews: some View {
        BoardListView(gameService: ServiceContainer.shared.gameService)
    }
}
