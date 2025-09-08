import SwiftUI

struct RootView: View {
    @State private var boardsNavigationPath = NavigationPath()
    
    var body: some View {
        TabView {
            NavigationStack(path: $boardsNavigationPath) {
                BoardListView(
                    gameService: ServiceContainer.shared.gameService, 
                    repository: ServiceContainer.shared.boardRepository,
                    navigationPath: $boardsNavigationPath
                )
            }
            .tabItem { Label("Boards", systemImage: "square.grid.3x3.fill") }
            NavigationStack { PatternsView() }
                .tabItem { Label("Patterns", systemImage: "square.3.layers.3d") }
            NavigationStack { AboutView() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

#Preview {
    RootView()
}
