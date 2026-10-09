//
//  AppModel.swift
//  Amaris
//
//  App-wide state: Goodreads sync, cover fetching and CSV import.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AppModel {
    let goodreads = GoodreadsSync()
    let coverFetcher = CoverFetcher()

    /// Set from the File menu; the main window shows the file picker.
    var isImportingCSV = false
    var message: String?

    /// The Add Quotes sheet, optionally preselecting a book.
    var isAddingQuotes = false
    private(set) var addQuotesBook: Book?

    func startAddingQuotes(for book: Book? = nil) {
        addQuotesBook = book
        isAddingQuotes = true
    }

    var isBusy: Bool { goodreads.isSyncing || coverFetcher.isRunning }

    /// Goodreads first (covers match my editions), then Open Library for any gaps.
    func syncNow(in context: ModelContext) async {
        message = nil
        await goodreads.sync(in: context)
        await coverFetcher.fetchMissingCovers(in: context)
        let stillMissing = coverFetcher.total - coverFetcher.found
        if stillMissing > 0 {
            message = "\(stillMissing) books have no cover."
        }
    }

    /// Syncs now and then hourly, for as long as the calling task lives.
    func syncPeriodically(in context: ModelContext) async {
        while !Task.isCancelled {
            await syncNow(in: context)
            try? await Task.sleep(for: GoodreadsSync.syncInterval)
        }
    }

    func importCSV(from url: URL, into context: ModelContext) async {
        do {
            // Sandboxed apps may only read files the user picked, and only
            // between these two calls.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let text = try String(contentsOf: url, encoding: .utf8)
            let summary = try GoodreadsImporter.importCSV(text, into: context)
            await syncNow(in: context)
            message = "Imported \(summary.booksAdded) new books and \(summary.quotesAdded) quotes."
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }

    var statusText: String? {
        if goodreads.isSyncing { return "Syncing with Goodreads…" }
        if coverFetcher.isRunning { return "Fetching covers \(coverFetcher.completed)/\(coverFetcher.total)…" }
        if let error = goodreads.lastError { return error }
        if let message { return message }
        if let date = goodreads.lastSyncedAt {
            return "Synced at \(date.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }
}
