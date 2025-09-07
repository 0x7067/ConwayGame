import SwiftUI

struct CreateBoardRoot: View {
    let gameService: GameService
    var onCreated: ((UUID) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CreateBoardView(gameService: gameService, onCreated: { id in
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

struct CreateBoardRoot_Previews: PreviewProvider {
    static var previews: some View {
        CreateBoardRoot(gameService: ServiceContainer.shared.gameService)
    }
}
