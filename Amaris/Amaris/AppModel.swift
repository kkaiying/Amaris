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
    var isImportingShelfPage = false
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

    /// True when macOS opened Amaris at login; the first window closes straight away.
    var launchedAtLogin = false

    /// Called by the main window when it first appears.
    func consumeQuietLaunch() -> Bool {
        defer { launchedAtLogin = false }
        return launchedAtLogin
    }

    private var backgroundSync: Task<Void, Never>?
    private var widgetRefresh: Task<Void, Never>?

    /// After the Mac wakes. The hourly sync is often already starting then (its
    /// timer ran on through sleep); cancelling it mid-download would leave
    /// nothing syncing for another hour, so a sync under way is left to finish.
    func syncAfterWake() {
        guard !goodreads.isSyncing else { return }
        startBackgroundSync()
    }

    /// Syncs now and then hourly, whether or not a window is open. Calling it
    /// again (new Goodreads account, Mac woke up) restarts the cycle.
    func startBackgroundSync() {
        backgroundSync?.cancel()
        let context = AmarisStore.shared.mainContext
        backgroundSync = Task {
            while !Task.isCancelled {
                await syncNow(in: context)
                try? await Task.sleep(for: GoodreadsSync.syncInterval)
            }
        }

        // Any saved change (sync, import, quotes, edits) refreshes the widgets.
        if widgetRefresh == nil {
            widgetRefresh = Task {
                for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                    WidgetData.reloadWidgets()
                }
            }
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

    /// Fills in real start dates from a saved Goodreads shelf page (HTML).
    func importStartDates(from url: URL, into context: ModelContext) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let html = try String(contentsOf: url, encoding: .utf8)
            let sessions = GoodreadsShelfPage.sessions(fromHTML: html)
            guard !sessions.isEmpty else {
                message = "No start dates found. Save the shelf page with the \u{201C}date started\u{201D} column visible."
                return
            }
            let summary = try StartDateImporter.apply(sessions, to: context)
            message = "Start dates: \(summary.updated) updated, \(summary.alreadyCorrect) already correct"
                + (summary.keptManualEdits > 0 ? ", \(summary.keptManualEdits) kept (edited by you)." : ".")
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
