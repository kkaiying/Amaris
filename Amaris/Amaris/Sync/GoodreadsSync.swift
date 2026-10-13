//
//  GoodreadsSync.swift
//  Amaris
//
//  Keeps the database in step with Goodreads shelves:
//  - currently-reading → the book is started (start = date shelved)
//  - read              → the open reading is finished (finish = date read)
//  - did-not-finish    → the open reading ends as DNF
//  - on-hold (custom)  → the open reading is paused; taking it off resumes it
//  Also uses Goodreads covers, which match the edition I shelved.
//
//  Never overwrites hand-edited dates, manual covers, or a rating edited in the app.
//

import Foundation
import Observation
import SwiftData

struct SyncSummary: Equatable {
    var booksAdded = 0
    var started = 0
    var finished = 0
    var dnf = 0
    var paused = 0
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
            applyRating(of: item, to: book)

            // Only a move to a different shelf changes status or starts/ends a
            // reading, so edits made in the app (e.g. marking DNF) aren't undone.
            let movedShelf = book.goodreadsShelf != shelf.rawValue
            book.goodreadsShelf = shelf.rawValue
            // Same idea for on-hold: only putting it on or taking it off counts.
            let changedHold = book.goodreadsOnHold != item.isOnHold
            book.goodreadsOnHold = item.isOnHold

            switch shelf {
            case .currentlyReading:
                let start = item.dateAdded.map(calendar.startOfDay) ?? calendar.startOfDay(for: today)
                var open = book.openReading
                if let open {
                    if open.startIsEstimated, !open.datesEditedManually {
                        open.startedAt = start
                        open.startIsEstimated = false
                    }
                } else if movedShelf {
                    let reading = Reading(book: book, startedAt: start, source: .goodreadsRSS)
                    context.insert(reading)
                    open = reading
                    summary.started += 1
                }
                if movedShelf { book.status = .reading }
                // The feed doesn't say when a book went on hold, so it's the day
                // sync notices (editable in the app).
                if changedHold, let open {
                    if item.isOnHold {
                        open.pause(on: today)
                        summary.paused += 1
                    } else {
                        open.resume(on: today)
                    }
                }

            case .read:
                guard let finish = item.readAt else { break }
                if let latest = book.latestReading {
                    // Also picks up a "date read" corrected on Goodreads.
                    if !latest.datesEditedManually, latest.finishedAt != finish {
                        if latest.finishedAt == nil { summary.finished += 1 }
                        latest.resume(on: finish)
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
                if movedShelf { book.status = .read }

            case .didNotFinish:
                if movedShelf {
                    if let open = book.openReading, !open.datesEditedManually {
                        let end = item.dateAdded.map(calendar.startOfDay) ?? calendar.startOfDay(for: today)
                        open.resume(on: end)
                        open.finishedAt = end
                        open.outcome = .dnf
                        summary.dnf += 1
                    }
                    book.status = .dnf
                }
            }

            if let url = item.imageURL, wantsGoodreadsCover(book) {
                covers.append((book, url))
            }
        }
        return covers
    }

    /// Fills in a missing rating, and follows a re-rating on Goodreads. The feed
    /// only has whole stars, so a rating that already rounds to them (e.g. a
    /// quarter-star one from the CSV or the app) is left alone.
    static func applyRating(of item: FeedItem, to book: Book) {
        let lastSeen = book.goodreadsRating
        book.goodreadsRating = item.rating
        guard let whole = item.rating, let rating = item.preciseRating else { return }
        if let current = book.rating {
            let rerated = lastSeen != nil && lastSeen != whole
            guard rerated, abs(current - Double(whole)) > 0.5 else { return }
        }
        book.rating = rating
    }

    /// Goodreads covers replace Open Library ones, but never a manual cover.
    static func wantsGoodreadsCover(_ book: Book) -> Bool {
        switch book.coverSource {
        case .manual: false
        case .goodreads: !CoverStore.hasCover(for: book)
        case .openLibrary, nil: true
        }
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
            let shelves = try await GoodreadsFeed.fetchAllShelves(userID: userID, session: session)
            // Order matters: start books before finishing them.
            for shelf in [Shelf.currentlyReading, .read, .didNotFinish] {
                covers += try FeedApplier.apply(shelves[shelf] ?? [], shelf: shelf, to: context, summary: &summary)
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
