//
//  ContentView.swift
//  Amaris
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Temporary screen to check the import works. Replaced by the real
/// library / quotes / calendar views later.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var books: [Book]
    @Query private var quotes: [Quote]

    @State private var coverFetcher = CoverFetcher()
    @State private var isPickingFile = false
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
        .frame(minWidth: 520, minHeight: 480)
        .fileImporter(isPresented: $isPickingFile,
                      allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            handlePickedFile(result)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Amaris").font(.largeTitle)
            Text("\(books.count) books · \(quotes.count) quotes · \(books.filter { $0.coverFileName != nil }.count) covers")
                .foregroundStyle(.secondary)

            HStack {
                Button("Import Goodreads CSV…") { isPickingFile = true }
                Button("Fetch Missing Covers") { fetchCovers() }
                    .disabled(coverFetcher.isRunning || books.isEmpty)
            }

            if coverFetcher.isRunning {
                ProgressView(value: Double(coverFetcher.completed), total: Double(max(coverFetcher.total, 1))) {
                    Text("Fetching covers… \(coverFetcher.completed)/\(coverFetcher.total)")
                }
                .frame(width: 300)
            } else if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
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
            fetchCovers()
        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }

    private func fetchCovers() {
        Task {
            await coverFetcher.fetchMissingCovers(in: context)
            let stillMissing = coverFetcher.total - coverFetcher.found
            message = coverFetcher.total == 0
                ? "All books already have covers."
                : "Found \(coverFetcher.found) of \(coverFetcher.total) covers"
                    + (stillMissing > 0 ? " · \(stillMissing) still missing." : ".")
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
