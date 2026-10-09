//
//  AmarisApp.swift
//  Amaris
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import SwiftUI
import SwiftData

@main
struct AmarisApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(AmarisStore.shared)
        .commands {
            CommandGroup(after: .importExport) {
                Button("Import Goodreads CSV…") { model.isImportingCSV = true }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
