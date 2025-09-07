import SwiftUI

struct BoardListView: View {
    @StateObject private var vm: BoardListViewModel
    @State private var createdId: UUID?
    @State private var navigateToCreated: Bool = false
    @State private var renamingBoard: Board?
    @State private var newName: String = ""
    @State private var showingCreate: Bool = false

    init(gameService: GameService, repository: BoardRepository) {
        _vm = StateObject(wrappedValue: BoardListViewModel(service: gameService, repository: repository))
    }

    var body: some View {
        ZStack {
            // Hidden link for programmatic navigation to newly created board
            NavigationLink(isActive: $navigateToCreated) {
                if let id = createdId {
                    GameBoardView(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository, boardId: id)
                }
            } label: { EmptyView() }

            List {
                ForEach(vm.boards, id: \.id) { board in
                    NavigationLink(destination: GameBoardView(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository, boardId: board.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(board.name)
                                Text("Created: \(board.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(board.width)x\(board.height)")
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
                Button {
                    showingCreate = true
                } label: { Image(systemName: "plus") }
            }
        }
        .task { await vm.load() }
        .fullScreenCover(isPresented: $showingCreate) {
            CreateBoardRoot(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository, onCreated: { id in
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
                                try? await ServiceContainer.shared.boardRepository.rename(id: b.id, newName: nameTrimmed)
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

#Preview {
    BoardListView(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository)
}
