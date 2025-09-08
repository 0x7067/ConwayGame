import SwiftUI

struct CreateBoardRoot: View {
    let gameService: GameService
    let repository: BoardRepository
    var onCreated: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CreateBoardView(gameService: gameService, repository: repository, onCreated: { id in
                onCreated?(id)
            })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    CreateBoardRoot(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository)
}
