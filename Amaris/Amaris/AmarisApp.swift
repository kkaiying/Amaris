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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AmarisStore.shared)
    }
}
