import SwiftUI
import ConwayGameEngine
import FactoryKit

struct BoardListView: View {
    @StateObject private var vm = BoardListViewModel()
    @State private var createdId: UUID?
    @State private var navigateToCreated: Bool = false
    @State private var renamingBoard: Board?
    @State private var newName: String = ""
    @State private var showingCreate: Bool = false
    @State private var showingSortOptions: Bool = false
    @State private var searchText: String = ""
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var navigationPath: NavigationPath
    @Injected(\.boardRepository) private var boardRepository: BoardRepository

    init(navigationPath: Binding<NavigationPath>) {
        _navigationPath = navigationPath
    }

    var body: some View {
        ZStack {
            // Handle programmatic navigation to newly created board
            if navigateToCreated, let id = createdId {
                Button("") {
                    navigationPath.append(id)
                    navigateToCreated = false
                }
                .hidden()
                .onAppear {
                    navigationPath.append(id)
                    navigateToCreated = false
                }
            }

            VStack(spacing: 0) {
                // Search and status bar
                VStack(spacing: 8) {
                    HStack {
                        SearchBar(text: $searchText) { query in
                            Task { await vm.search(query: query) }
                        }
                        
                        Button(action: { showingSortOptions = true }) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                    
                    if vm.totalCount > 0 {
                        HStack {
                            Text("\(vm.totalCount) board\(vm.totalCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vm.sortOption.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                
                // Board list
                if vm.isLoading && vm.boards.isEmpty {
                    Spacer()
                    ProgressView("Loading boards...")
                    Spacer()
                } else if vm.boards.isEmpty && !vm.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No boards found" : "No boards match your search")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty {
                            Button("Clear Search") {
                                searchText = ""
                                Task { await vm.search(query: "") }
                            }
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(vm.boards, id: \.id) { board in
                            BoardRowView(
                                board: board,
                                onRename: { renamingBoard = board; newName = board.name }
                            )
                            .onAppear {
                                if vm.shouldLoadMoreContent(for: board) {
                                    Task { await vm.loadNextPage() }
                                }
                            }
                        }
                        .onDelete { indices in
                            Task {
                                for index in indices {
                                    await vm.delete(id: vm.boards[index].id)
                                }
                            }
                        }
                        
                        // Loading more indicator
                        if vm.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .refreshable {
                        await vm.refresh()
                    }
                }
            }
            
        }
        .navigationTitle("Boards")
        .navigationDestination(for: UUID.self) { boardId in
            GameBoardView(
                boardId: boardId,
                navigationPath: $navigationPath,
                themeManager: themeManager
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingCreate = true
                } label: { Image(systemName: "plus") }
            }
        }
        .task { await vm.loadFirstPage() }
        .gameErrorAlert(
            gameError: $vm.gameError,
            context: .boardList,
            onRecoveryAction: vm.handleRecoveryAction
        )
        .confirmationDialog("Sort Boards", isPresented: $showingSortOptions) {
            ForEach(BoardSortOption.allCases, id: \.self) { option in
                Button(option.displayName) {
                    Task { await vm.changeSortOption(option) }
                }
            }
        }
        .fullScreenCover(isPresented: $showingCreate) {
            CreateBoardRoot(onCreated: { id in
                createdId = id
                navigateToCreated = true
                Task { await vm.refresh() }
            })
        }
        .sheet(item: $renamingBoard) { board in
            RenameSheetView(
                board: board,
                newName: $newName,
                onCancel: { renamingBoard = nil },
                onSave: { name in
                    Task {
                        try? await boardRepository.rename(id: board.id, newName: name)
                        renamingBoard = nil
                        await vm.refresh()
                    }
                }
            )
        }
    }
}

struct BoardRowView: View {
    let board: Board
    let onRename: () -> Void
    
    var body: some View {
        NavigationLink(value: board.id) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(board.name)
                        .font(.headline)
                    Text("Created: \(board.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if board.currentGeneration > 0 {
                        Text("Generation: \(board.currentGeneration)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(board.width)×\(board.height)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if board.isActive {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .contextMenu {
            Button("Rename") { onRename() }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchCommitted: (String) -> Void
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search boards...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: text) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
                        if !Task.isCancelled {
                            onSearchCommitted(newValue)
                        }
                    }
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearchCommitted("")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct RenameSheetView: View {
    let board: Board
    @Binding var newName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Rename Board")) {
                    TextField("Name", text: $newName)
                }
            }
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { onCancel(); return }
                        onSave(trimmedName)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        BoardListView(navigationPath: $path)
    }
}
