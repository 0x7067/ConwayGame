import Foundation
import ConwayGameEngine
import FactoryKit

@MainActor
final class BoardListViewModel: ObservableObject {
    @Published var boards: [Board] = []
    @Published var gameError: GameError?
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMorePages = false
    @Published var totalCount = 0
    @Published var searchQuery = ""
    @Published var sortOption: BoardSortOption = .createdAtDescending
    
    private var currentPage = 0
    private var allLoadedBoards: [Board] = []
    
    @Injected(\.gameService) private var service: GameService
    @Injected(\.boardRepository) private var repository: BoardRepository
    @Injected(\.gameEngineConfiguration) private var gameEngineConfiguration

    func loadFirstPage() async {
        await loadPage(reset: true)
    }
    
    func loadNextPage() async {
        guard !isLoadingMore && hasMorePages else { return }
        await loadPage(reset: false)
    }
    
    func refresh() async {
        await loadPage(reset: true)
    }
    
    func search(query: String) async {
        searchQuery = query
        await loadPage(reset: true)
    }
    
    func changeSortOption(_ newSortOption: BoardSortOption) async {
        sortOption = newSortOption
        await loadPage(reset: true)
    }
    
    private func loadPage(reset: Bool) async {
        if reset {
            isLoading = true
            currentPage = 0
            allLoadedBoards.removeAll()
            gameError = nil
        } else {
            isLoadingMore = true
            currentPage += 1
        }
        
        do {
            let offset = currentPage * gameEngineConfiguration.paginationPageSize
            let page: BoardListPage
            
            if searchQuery.isEmpty {
                page = try await repository.loadBoardsPaginated(
                    offset: offset,
                    limit: gameEngineConfiguration.paginationPageSize,
                    sortBy: sortOption
                )
            } else {
                page = try await repository.searchBoards(
                    query: searchQuery,
                    offset: offset,
                    limit: gameEngineConfiguration.paginationPageSize,
                    sortBy: sortOption
                )
            }
            
            if reset {
                allLoadedBoards = page.boards
            } else {
                allLoadedBoards.append(contentsOf: page.boards)
            }
            
            boards = allLoadedBoards
            hasMorePages = page.hasMorePages
            totalCount = page.totalCount
            gameError = nil
            
        } catch {
            if reset {
                boards = []
                allLoadedBoards = []
                hasMorePages = false
                totalCount = 0
            }
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError("Failed to load boards: \(error.localizedDescription)")
            }
        }
        
        isLoading = false
        isLoadingMore = false
    }

    @available(*, deprecated, message: "Use loadFirstPage() instead for better performance")
    func load() async {
        await loadFirstPage()
    }

    func createRandomBoard(name: String = "Board", width: Int? = nil, height: Int? = nil, density: Double? = nil) async {
        let actualWidth = width ?? gameEngineConfiguration.defaultBoardWidth
        let actualHeight = height ?? gameEngineConfiguration.defaultBoardHeight
        let actualDensity = density ?? gameEngineConfiguration.defaultRandomDensity
        
        var cells = Array(repeating: Array(repeating: false, count: actualWidth), count: actualHeight)
        for y in 0..<actualHeight { for x in 0..<actualWidth { cells[y][x] = Double.random(in: 0...1) < actualDensity } }
        let boardId = await service.createBoard(cells)
        
        // Update the board name if different from default
        if name != "Board-\(boardId.uuidString.prefix(8))" {
            try? await repository.rename(id: boardId, newName: name)
        }
        
        await refresh()
    }

    func delete(id: UUID) async {
        do {
            try await repository.delete(id: id)
            // Remove from local arrays to avoid full refresh
            allLoadedBoards.removeAll { $0.id == id }
            boards.removeAll { $0.id == id }
            totalCount = max(0, totalCount - 1)
        } catch {
            // If delete fails, reload to ensure consistency
            await load()
            if let gameError = error as? GameError {
                self.gameError = gameError
            } else {
                self.gameError = .persistenceError("Failed to delete board: \(error.localizedDescription)")
            }
        }
    }
    
    func shouldLoadMoreContent(for board: Board) -> Bool {
        guard hasMorePages && !isLoadingMore else { return false }
        // Trigger loading when we're near the end (within lookahead threshold)
        if let lastBoard = boards.last, board.id == lastBoard.id {
            return true
        }
        if let index = boards.firstIndex(where: { $0.id == board.id }) {
            return index >= boards.count - DesignTokens.Pagination.lookaheadTrigger
        }
        return false
    }
    
    func handleRecoveryAction(_ action: ErrorRecoveryAction) {
        switch action {
        case .retry:
            Task { await load() }
        case .goBack, .goToBoardList, .createNew, .continueWithoutSaving, .cancel, .contactSupport, .resetBoard, .tryAgain:
            break
        }
    }
}

