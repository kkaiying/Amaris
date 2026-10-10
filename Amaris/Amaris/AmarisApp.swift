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
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private var model: AppModel { appDelegate.model }

    init() {
        AmarisFonts.register()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(model)
        }
        .modelContainer(AmarisStore.shared)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Quotes…") { model.startAddingQuotes() }
                    .keyboardShortcut("n")
            }
            CommandGroup(after: .importExport) {
                Button("Import Goodreads CSV…") { model.isImportingCSV = true }
                Button("Import Start Dates from Goodreads Page…") { model.isImportingShelfPage = true }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }

        // Stays while Amaris runs in the background with no windows open.
        MenuBarExtra("Amaris", systemImage: "books.vertical") {
            MenuBarContent()
                .environment(model)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(model.statusText ?? "Not synced yet")
        Button("Sync Now") {
            Task { await model.syncNow(in: AmarisStore.shared.mainContext) }
        }
        .disabled(model.isBusy || model.goodreads.userID == nil)
        Divider()
        Button("Open Amaris") {
            openWindow(id: "main")
            NSApp.activate()
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit Amaris") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
