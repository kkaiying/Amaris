//
//  GoodreadsSync.swift
//  Amaris
//
//  Keeps the database in step with Goodreads shelves:
//  - currently-reading → the book is started (start = date shelved)
//  - read              → the open reading is finished (finish = date read)
//  - did-not-finish    → the open reading ends as DNF
//  Also uses Goodreads covers, which match the edition I shelved.
//
//  Never overwrites hand-edited dates, manual covers, or a precise rating.
//

import Foundation
import Observation
import SwiftData

struct SyncSummary: Equatable {
    var booksAdded = 0
    var started = 0
    var finished = 0
    var dnf = 0
    var coversUpdated = 0
}

enum FeedApplier {
    /// Covers to download after applying a shelf: (book, Goodreads image URL).
    typealias CoverRequest = (book: Book, url: URL)

    static func apply(_ items: [FeedItem], shelf: Shelf, to context: ModelContext,
                      today: Date = .now, summary: inout SyncSummary) throws -> [CoverRequest] {
        let books = try context.fetch(FetchDescriptor<Book>())
        var booksByID: [String: Book] = [:]
        for book in books {
            if let id = book.goodreadsID { booksByID[id] = book }
        }
        let calendar = Calendar.current
        var covers: [CoverRequest] = []

        for item in items {
            // Old reads without a date aren't tracked.
            if shelf == .read, item.readAt == nil { continue }

            let book: Book
            if let existing = booksByID[item.bookID] {
                book = existing
            } else {
                // A DNF the app has never seen has no dates: library only.
                book = Book(title: item.title, author: item.author)
                book.goodreadsID = item.bookID
                context.insert(book)
                booksByID[item.bookID] = book
                summary.booksAdded += 1
            }

            book.pageCount = book.pageCount ?? item.pageCount
            // The feed rounds ratings to whole stars; only fill in a missing one.
            if book.rating == nil, let rating = item.rating { book.rating = Double(rating) }

            switch shelf {
            case .currentlyReading:
                book.status = .reading
                let start = item.dateAdded.map(calendar.startOfDay) ?? calendar.startOfDay(for: today)
                if let open = openReading(of: book) {
                    if open.startIsEstimated, !open.datesEditedManually {
                        open.startedAt = start
                        open.startIsEstimated = false
                    }
                } else {
                    context.insert(Reading(book: book, startedAt: start, source: .goodreadsRSS))
                    summary.started += 1
                }

            case .read:
                book.status = .read
                guard let finish = item.readAt else { break }
                if let latest = latestReading(of: book) {
                    if !latest.datesEditedManually, latest.finishedAt != finish {
                        if latest.finishedAt == nil { summary.finished += 1 }
                        latest.finishedAt = finish
                        latest.outcome = .read
                    }
                } else {
                    let reading = Reading(book: book, startedAt: estimatedStart(endingAt: finish, in: books),
                                          finishedAt: finish, source: .goodreadsRSS)
                    reading.startIsEstimated = true
                    reading.outcome = .read
                    context.insert(reading)
                    summary.finished += 1
                }

            case .didNotFinish:
                book.status = .dnf
                if let open = openReading(of: book), !open.datesEditedManually {
                    open.finishedAt = item.dateAdded.map(calendar.startOfDay) ?? calendar.startOfDay(for: today)
                    open.outcome = .dnf
                    summary.dnf += 1
                }
            }

            if let url = item.imageURL, wantsGoodreadsCover(book) {
                covers.append((book, url))
            }
        }
        return covers
    }

    /// Goodreads covers replace Open Library ones, but never a manual cover.
    static func wantsGoodreadsCover(_ book: Book) -> Bool {
        switch book.coverSource {
        case .manual: false
        case .goodreads: !CoverStore.hasCover(for: book)
        case .openLibrary, nil: true
        }
    }

    private static func openReading(of book: Book) -> Reading? {
        (book.readings ?? []).first { $0.finishedAt == nil }
    }

    private static func latestReading(of book: Book) -> Reading? {
        (book.readings ?? []).max { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
    }

    /// Same rule as the CSV backfill: the previous finish, at most 30 days back.
    private static func estimatedStart(endingAt end: Date, in books: [Book]) -> Date {
        let cap = Calendar.current.date(byAdding: .day, value: -BackfillPlanner.maxEstimatedDays, to: end) ?? end
        let previous = books
            .flatMap { $0.readings ?? [] }
            .compactMap(\.finishedAt)
            .filter { $0 < end }
            .max()
        return max(previous ?? cap, cap)
    }
}

@Observable
final class GoodreadsSync {
    static let userIDKey = "goodreadsUserID"
    static let syncInterval: Duration = .seconds(60 * 60)

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AmarisStore.appGroupID) ?? .standard
    }

    var userID: String? = GoodreadsSync.defaults.string(forKey: userIDKey) {
        didSet { Self.defaults.set(userID, forKey: Self.userIDKey) }
    }

    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    private(set) var lastSummary: SyncSummary?
    private(set) var lastError: String?

    private let coverFetcher = CoverFetcher()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["User-Agent": "Amaris/1.0 (personal reading tracker)"]
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    func sync(in context: ModelContext) async {
        guard let userID, !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        do {
            var summary = SyncSummary()
            var covers: [FeedApplier.CoverRequest] = []
            // Order matters: start books before finishing them.
            for shelf in [Shelf.currentlyReading, .read, .didNotFinish] {
                let items = try await GoodreadsFeed.fetchShelf(shelf, userID: userID, session: session)
                covers += try FeedApplier.apply(items, shelf: shelf, to: context, summary: &summary)
            }
            try context.save()

            for (book, url) in covers {
                if let data = await coverFetcher.fetchImage(url),
                   (try? CoverStore.save(data, for: book, source: .goodreads)) != nil {
                    summary.coversUpdated += 1
                }
            }
            try context.save()

            lastSummary = summary
            lastSyncedAt = .now
        } catch {
            lastError = "Goodreads sync failed: \(error.localizedDescription)"
        }
    }
}
