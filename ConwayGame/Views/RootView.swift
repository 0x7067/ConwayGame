import SwiftUI

struct RootView: View {
    @State private var boardsNavigationPath = NavigationPath()
    @StateObject private var themeManager = ServiceContainer.shared.themeManager
    
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
            NavigationStack { 
                SettingsView()
                    .environmentObject(themeManager)
            }
                .tabItem { Label("Settings", systemImage: "gear") }
            NavigationStack { AboutView() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .environmentObject(themeManager)
    }
}

#Preview {
    RootView()
}
