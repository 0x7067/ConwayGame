import SwiftUI

enum ThemePreference: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum PlaySpeed: CaseIterable {
    case normal
    case fast
    case faster
    case turbo
    
    var displayName: String {
        switch self {
        case .normal: return "1x"
        case .fast: return "2x"
        case .faster: return "4x"
        case .turbo: return "8x"
        }
    }
    
    var interval: UInt64 {
        switch self {
        case .normal: return 500_000_000
        case .fast: return 250_000_000
        case .faster: return 125_000_000
        case .turbo: return 62_500_000
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var themePreference: ThemePreference {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
        }
    }
    
    @Published var defaultBoardSize: Int {
        didSet {
            UserDefaults.standard.set(defaultBoardSize, forKey: "defaultBoardSize")
        }
    }
    
    @Published var defaultPlaySpeed: PlaySpeed {
        didSet {
            UserDefaults.standard.set(defaultPlaySpeed.displayName, forKey: "defaultPlaySpeed")
        }
    }
    
    init() {
        let savedPreference = UserDefaults.standard.string(forKey: "themePreference") ?? ThemePreference.system.rawValue
        self.themePreference = ThemePreference(rawValue: savedPreference) ?? .system
        
        let savedBoardSize = UserDefaults.standard.integer(forKey: "defaultBoardSize")
        self.defaultBoardSize = savedBoardSize > 0 ? savedBoardSize : 15
        
        let savedSpeedName = UserDefaults.standard.string(forKey: "defaultPlaySpeed") ?? PlaySpeed.normal.displayName
        self.defaultPlaySpeed = PlaySpeed.allCases.first { $0.displayName == savedSpeedName } ?? .normal
    }
    
    var colorScheme: ColorScheme? {
        switch themePreference {
        case .system: return nil // Let system decide
        case .light: return .light
        case .dark: return .dark
        }
    }
}