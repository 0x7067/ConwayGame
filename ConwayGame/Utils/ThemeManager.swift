import SwiftUI
import ConwayGameEngine

public enum ThemePreference: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

public class ThemeManager: ObservableObject {
    @Published public var themePreference: ThemePreference {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
        }
    }
    
    @Published public var defaultBoardSize: Int {
        didSet {
            UserDefaults.standard.set(defaultBoardSize, forKey: "defaultBoardSize")
        }
    }
    
    @Published public var defaultPlaySpeed: PlaySpeed {
        didSet {
            UserDefaults.standard.set(defaultPlaySpeed.displayName, forKey: "defaultPlaySpeed")
        }
    }
    
    private let playSpeedConfiguration: PlaySpeedConfiguration
    
    public init(playSpeedConfiguration: PlaySpeedConfiguration = .default) {
        self.playSpeedConfiguration = playSpeedConfiguration
        
        let savedPreference = UserDefaults.standard.string(forKey: "themePreference") ?? ThemePreference.system.rawValue
        self.themePreference = ThemePreference(rawValue: savedPreference) ?? .system
        
        let savedBoardSize = UserDefaults.standard.integer(forKey: "defaultBoardSize")
        self.defaultBoardSize = savedBoardSize > 0 ? savedBoardSize : 15
        
        let savedSpeedName = UserDefaults.standard.string(forKey: "defaultPlaySpeed") ?? PlaySpeed.normal.displayName
        self.defaultPlaySpeed = PlaySpeed.allCases.first { $0.displayName == savedSpeedName } ?? .normal
    }
    
    public func interval(for speed: PlaySpeed) -> UInt64 {
        return playSpeedConfiguration.interval(for: speed)
    }
    
    public var colorScheme: ColorScheme? {
        switch themePreference {
        case .system: return nil // Let system decide
        case .light: return .light
        case .dark: return .dark
        }
    }
}