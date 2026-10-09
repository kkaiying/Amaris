//
//  AmarisStore.swift
//  Amaris
//
//  Creates the database in the shared App Group container, so the app and
//  the widget extension read and write the same file.
//

import Foundation
import SwiftData

enum AmarisStore {
    static let appGroupID = "group.com.linna.amaris"

    static let schema = Schema([Book.self, Reading.self, Quote.self])

    /// The folder both the app and the widget can access.
    static var sharedContainerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App Group \(appGroupID) is not configured for this target")
        }
        return url
    }

    /// Cached book covers live next to the database.
    static var coversDirectory: URL {
        let url = sharedContainerURL.appending(path: "Covers", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// The single container used by the running app.
    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("Could not open the Amaris database: \(error)")
        }
    }()
}
