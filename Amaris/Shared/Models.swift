//
//  Models.swift
//  Amaris
//
//  The database schema. Shared by the app and the widget extension.
//
//  Kept CloudKit-compatible so iCloud sync to an iPhone can be added later:
//  no unique constraints, every property has a default or is optional, and
//  relationships are optional.
//

import Foundation
import SwiftData

enum BookStatus: String, Codable, CaseIterable {
    case reading
    case read
    case dnf
}

enum DataSource: String, Codable {
    case goodreadsCSV
    case goodreadsRSS
    case manual
}

/// Where a cached cover came from. Goodreads covers match the edition I
/// shelved; Open Library is the fallback; manual covers are never replaced.
enum CoverSource: String, Codable {
    case goodreads
    case openLibrary
    case manual
}

@Model
final class Book {
    var goodreadsID: String?
    var kindleBookID: String?
    var isbn13: String?

    var title: String = ""
    var author: String = ""
    var pageCount: Int?

    /// Goodreads allows quarter stars (e.g. 3.75). `nil` means unrated.
    var rating: Double?

    /// File name of the locally cached cover inside the App Group container.
    var coverFileName: String?
    var coverSourceRaw: String?

    // Stored as a raw string so SwiftData can persist and query it.
    var statusRaw: String = BookStatus.reading.rawValue

    /// The Goodreads shelf this book was on at the last sync. Sync only changes
    /// status and dates when the shelf changes, so edits made in the app stick.
    var goodreadsShelf: String?
    /// Whether the book was on the Goodreads on-hold shelf at the last sync.
    /// Like the shelf, only a change pauses or resumes, so app edits stick.
    var goodreadsOnHold: Bool = false
    /// The whole-star rating Goodreads gave at the last sync, to spot re-ratings.
    var goodreadsRating: Int?

    @Relationship(deleteRule: .cascade, inverse: \Reading.book)
    var readings: [Reading]? = []

    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]? = []

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .reading }
        set { statusRaw = newValue.rawValue }
    }

    var coverSource: CoverSource? {
        get { coverSourceRaw.flatMap(CoverSource.init(rawValue:)) }
        set { coverSourceRaw = newValue?.rawValue }
    }

    init(title: String, author: String, status: BookStatus = .reading) {
        self.title = title
        self.author = author
        self.statusRaw = status.rawValue
    }
}

/// One read-through of a book: the span the calendar fills with its cover.
@Model
final class Reading {
    var book: Book?

    var startedAt: Date?
    /// `nil` while still reading (the calendar fills through today).
    var finishedAt: Date?

    /// Whether this read ended by finishing or by DNF.
    var outcomeRaw: String?

    /// True when the start date was guessed by the backfill rules.
    var startIsEstimated: Bool = false
    /// Once a date is edited by hand, sync must never overwrite it.
    var datesEditedManually: Bool = false

    var sourceRaw: String = DataSource.manual.rawValue

    /// Stretches spent on hold, which the calendar leaves empty.
    var pauses: [ReadingPause] = []

    var outcome: BookStatus? {
        get { outcomeRaw.flatMap(BookStatus.init(rawValue:)) }
        set { outcomeRaw = newValue?.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(book: Book, startedAt: Date?, finishedAt: Date? = nil, source: DataSource) {
        self.book = book
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.sourceRaw = source.rawValue
    }
}

/// A stretch of a reading spent on hold: no cover from `start` up to (not
/// including) `end`. `end` is nil while the book is still on hold.
nonisolated struct ReadingPause: Codable, Hashable {
    var start: Date
    var end: Date?
}

@Model
final class Quote {
    var book: Book?
    var text: String = ""
    var isFavourite: Bool = false
    var sourceRaw: String = DataSource.manual.rawValue
    var createdAt: Date = Date.now
    /// Used by the widget to rotate fairly (least recently shown first).
    var lastShownAt: Date?

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(book: Book, text: String, source: DataSource) {
        self.book = book
        self.text = text
        self.sourceRaw = source.rawValue
    }
}
