//
//  CoverFetcher.swift
//  Amaris
//
//  Downloads missing book covers from Open Library and caches them in the
//  shared App Group container, where the widgets can read them offline.
//
//  1. By ISBN:            covers.openlibrary.org/b/isbn/{isbn}-L.jpg
//  2. Fallback by search: openlibrary.org/search.json?title=…&author=… → cover_i
//

import Foundation
import ImageIO
import Observation
import SwiftData

@Observable
final class CoverFetcher {
    private(set) var isRunning = false
    private(set) var completed = 0
    private(set) var total = 0
    private(set) var found = 0

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Amaris/1.0 (personal reading tracker)"]
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    /// Fetches covers for every book that doesn't have a cached one yet.
    func fetchMissingCovers(in context: ModelContext) async {
        guard !isRunning else { return }
        let books = (try? context.fetch(FetchDescriptor<Book>())) ?? []
        let missing = books.filter { !CoverStore.hasCover(for: $0) }

        isRunning = true
        completed = 0
        found = 0
        total = missing.count
        defer { isRunning = false }

        // Sequential on purpose: Open Library rate-limits ISBN lookups.
        for book in missing {
            if let data = await downloadCover(isbn: book.isbn13, title: book.title, author: book.author),
               (try? CoverStore.save(data, for: book, source: .openLibrary)) != nil {
                found += 1
            }
            completed += 1
            if completed.isMultiple(of: 10) { try? context.save() }
        }
        try? context.save()
    }

    private func downloadCover(isbn: String?, title: String, author: String) async -> Data? {
        if let isbn, let url = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg?default=false"),
           let data = await fetchImage(url) {
            return data
        }
        guard let coverID = await searchCoverID(title: title, author: author),
              let url = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg?default=false")
        else { return nil }
        return await fetchImage(url)
    }

    private func searchCoverID(title: String, author: String) async -> Int? {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        components.queryItems = [
            URLQueryItem(name: "title", value: Self.baseTitle(title)),
            URLQueryItem(name: "author", value: author),
            URLQueryItem(name: "fields", value: "cover_i"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }

        struct SearchResult: Decodable {
            struct Doc: Decodable { let cover_i: Int? }
            let docs: [Doc]
        }
        let result = try? JSONDecoder().decode(SearchResult.self, from: data)
        return result?.docs.lazy.compactMap(\.cover_i).first
    }

    /// Returns the data only if it's a real image (not an error page or 1×1 placeholder).
    func fetchImage(_ url: URL) async -> Data? {
        guard let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, width > 10
        else { return nil }
        return data
    }

    /// "Crooked Kingdom (Six of Crows, #2)" → "Crooked Kingdom", for better search hits.
    nonisolated static func baseTitle(_ title: String) -> String {
        title.replacing(/\s*\([^()]*#[^()]*\)\s*$/, with: "")
    }
}
