import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { BoardListView(gameService: ServiceContainer.shared.gameService, repository: ServiceContainer.shared.boardRepository) }
                .tabItem { Label("Boards", systemImage: "square.grid.3x3.fill") }
            NavigationStack { PatternsView() }
                .tabItem { Label("Patterns", systemImage: "sparkles") }
            NavigationStack { AboutView() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview {
    RootView()
}
