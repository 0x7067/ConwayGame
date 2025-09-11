import SwiftUI
import ConwayGameEngine

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $themeManager.themePreference) {
                        ForEach(ThemePreference.allCases, id: \.self) { preference in
                            Text(preference.displayName)
                                .tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("System follows your device's appearance settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Board Creation") {
                    HStack {
                        Text("Default Size")
                        Spacer()
                        Stepper(
                            value: $themeManager.defaultBoardSize,
                            in: 5...UIConstants.maxBoardDimension,
                            step: 1
                        ) {
                            Text("\(themeManager.defaultBoardSize)×\(themeManager.defaultBoardSize)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Default size for new boards (5-\(UIConstants.maxBoardDimension)).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Gameplay") {
                    Picker("Default Speed", selection: $themeManager.defaultPlaySpeed) {
                        ForEach(PlaySpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName)
                                .tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Default playback speed when running simulations.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}