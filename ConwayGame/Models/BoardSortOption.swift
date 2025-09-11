import Foundation

public enum BoardSortOption: CaseIterable, Sendable {
    case createdAtDescending
    case createdAtAscending
    case nameAscending
    case nameDescending
    case generationDescending
    case generationAscending
    
    public var displayName: String {
        switch self {
        case .createdAtDescending:
            return "Newest First"
        case .createdAtAscending:
            return "Oldest First"
        case .nameAscending:
            return "Name A-Z"
        case .nameDescending:
            return "Name Z-A"
        case .generationDescending:
            return "Most Advanced"
        case .generationAscending:
            return "Least Advanced"
        }
    }
    
    public var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .createdAtDescending:
            return [NSSortDescriptor(keyPath: \BoardEntity.createdAt, ascending: false)]
        case .createdAtAscending:
            return [NSSortDescriptor(keyPath: \BoardEntity.createdAt, ascending: true)]
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \BoardEntity.name, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \BoardEntity.name, ascending: false)]
        case .generationDescending:
            return [NSSortDescriptor(keyPath: \BoardEntity.currentGeneration, ascending: false)]
        case .generationAscending:
            return [NSSortDescriptor(keyPath: \BoardEntity.currentGeneration, ascending: true)]
        }
    }
}

public struct BoardListPage: Sendable {
    public let boards: [Board]
    public let totalCount: Int
    public let hasMorePages: Bool
    public let currentPage: Int
    public let pageSize: Int
    
    public init(boards: [Board], totalCount: Int, hasMorePages: Bool, currentPage: Int, pageSize: Int) {
        self.boards = boards
        self.totalCount = totalCount
        self.hasMorePages = hasMorePages
        self.currentPage = currentPage
        self.pageSize = pageSize
    }
}