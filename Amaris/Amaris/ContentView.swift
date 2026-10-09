//
//  ContentView.swift
//  Amaris
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Temporary screen to check import and sync work. Replaced by the real
/// library / quotes / calendar views later.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var books: [Book]
    @Query private var quotes: [Quote]

    @State private var goodreads = GoodreadsSync()
    @State private var coverFetcher = CoverFetcher()
    @State private var isPickingFile = false
    @State private var profileText = ""
    @State private var message: String?

    private var booksNewestFirst: [Book] {
        books.sorted { latestDate($0) > latestDate($1) }
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 10) {
                    ForEach(booksNewestFirst) { book in
                        CoverImage(book: book)
                            .help("\(book.title) — \(book.author)")
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .frame(minWidth: 560, minHeight: 520)
        .fileImporter(isPresented: $isPickingFile,
                      allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handlePickedFile(result)
        }
        // Sync on launch and hourly while the window is open.
        .task(id: goodreads.userID) {
            while !Task.isCancelled {
                await syncNow()
                try? await Task.sleep(for: GoodreadsSync.syncInterval)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Amaris").font(.largeTitle)
            Text("\(books.count) books · \(quotes.count) quotes · \(books.filter { $0.coverFileName != nil }.count) covers")
                .foregroundStyle(.secondary)

            HStack {
                Button("Import Goodreads CSV…") { isPickingFile = true }
                Button("Sync Goodreads") { Task { await syncNow() } }
                    .disabled(goodreads.userID == nil || goodreads.isSyncing)
            }

            if goodreads.userID == nil {
                HStack {
                    TextField("Goodreads profile link", text: $profileText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                    Button("Connect") {
                        goodreads.userID = GoodreadsFeed.userID(from: profileText)
                        if goodreads.userID == nil { message = "That doesn't look like a Goodreads profile link." }
                    }
                }
            }

            status
        }
    }

    @ViewBuilder
    private var status: some View {
        if goodreads.isSyncing {
            ProgressView("Syncing with Goodreads…").controlSize(.small)
        } else if coverFetcher.isRunning {
            ProgressView(value: Double(coverFetcher.completed), total: Double(max(coverFetcher.total, 1))) {
                Text("Fetching covers… \(coverFetcher.completed)/\(coverFetcher.total)")
            }
            .frame(width: 300)
        } else if let error = goodreads.lastError {
            Text(error).font(.callout).foregroundStyle(.red)
        } else if let message {
            Text(message).font(.callout).foregroundStyle(.secondary)
        } else if let summary = goodreads.lastSummary, let date = goodreads.lastSyncedAt {
            Text("Synced \(date.formatted(date: .omitted, time: .shortened)): "
                 + "\(summary.started) started, \(summary.finished) finished, "
                 + "\(summary.coversUpdated) covers updated")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func handlePickedFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            // Sandboxed apps may only read files the user picked, and only
            // between these two calls.
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let text = try String(contentsOf: url, encoding: .utf8)
            let summary = try GoodreadsImporter.importCSV(text, into: context)
            message = "Imported: \(summary.booksAdded) new books, \(summary.booksUpdated) updated, "
                + "\(summary.readingsAdded) reading spans, \(summary.quotesAdded) quotes."
            Task { await syncNow() }
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }

    /// Goodreads first (covers match my editions), then Open Library for any gaps.
    private func syncNow() async {
        message = nil
        await goodreads.sync(in: context)
        await fillMissingCovers()
    }

    private func fillMissingCovers() async {
        await coverFetcher.fetchMissingCovers(in: context)
        let stillMissing = coverFetcher.total - coverFetcher.found
        if stillMissing > 0 {
            message = "\(stillMissing) books still have no cover."
        }
    }

    private func latestDate(_ book: Book) -> Date {
        let dates = (book.readings ?? []).map { $0.finishedAt ?? .distantFuture }
        return dates.max() ?? .distantPast
    }
}

#Preview {
    ContentView()
        .modelContainer(try! AmarisStore.makeContainer(inMemory: true))
}
