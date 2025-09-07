//
//  ConwayGameCodexApp.swift
//  ConwayGameCodex
//
//  Created by Pedro Guimarães on 9/7/25.
//

import SwiftUI

@main
struct ConwayGameCodexApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
