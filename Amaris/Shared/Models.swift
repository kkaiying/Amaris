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

    // Stored as a raw string so SwiftData can persist and query it.
    var statusRaw: String = BookStatus.reading.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Reading.book)
    var readings: [Reading]? = []

    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]? = []

    var status: BookStatus {
        get { BookStatus(rawValue: statusRaw) ?? .reading }
        set { statusRaw = newValue.rawValue }
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
