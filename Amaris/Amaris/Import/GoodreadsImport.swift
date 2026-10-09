//
//  GoodreadsImport.swift
//  Amaris
//
//  Imports a Goodreads library export (CSV) into the database:
//  books, estimated reading spans for the calendar, and quotes from reviews.
//

import Foundation
import SwiftData

/// One relevant row of the Goodreads export.
nonisolated struct GoodreadsRow: Equatable {
    var goodreadsID: String
    var title: String
    var author: String
    var isbn13: String?
    var rating: Double?
    var pageCount: Int?
    var dateRead: Date?
    var shelf: String
    var review: String

    static let readShelf = "read"
    static let currentlyReadingShelf = "currently-reading"
    static let dnfShelf = "did-not-finish"

    /// The rows Amaris cares about: dated reads, the current read, and DNFs.
    var isIncluded: Bool {
        switch shelf {
        case Self.readShelf: dateRead != nil
        case Self.currentlyReadingShelf, Self.dnfShelf: true
        default: false
        }
    }

    var status: BookStatus {
        switch shelf {
        case Self.readShelf: .read
        case Self.dnfShelf: .dnf
        default: .reading
        }
    }
}

nonisolated enum GoodreadsCSV {
    static func rows(fromCSV text: String) -> [GoodreadsRow] {
        CSVParser.parseWithHeader(text).compactMap(row(from:))
    }

    static func row(from fields: [String: String]) -> GoodreadsRow? {
        guard let id = fields["Book Id"]?.trimmed, !id.isEmpty else { return nil }
        return GoodreadsRow(
            goodreadsID: id,
            title: cleanText(fields["Title"] ?? ""),
            author: cleanText(fields["Author"] ?? ""),
            isbn13: cleanISBN(fields["ISBN13"]),
            rating: fields["My Rating"].flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil },
            pageCount: fields["Number of Pages"].flatMap { Int($0.trimmed) },
            dateRead: fields["Date Read"].flatMap(parseDate),
            shelf: fields["Exclusive Shelf"]?.trimmed ?? "",
            review: fields["My Review"] ?? ""
        )
    }

    /// Goodreads dates look like "2026/10/03". Stored as the start of that local day.
    static func parseDate(_ text: String) -> Date? {
        let parts = text.trimmed.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Removes zero-width characters and doubled spaces Goodreads leaves in titles and names.
    static func cleanText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacing(/\s+/, with: " ")
            .trimmed
    }

    /// Raw exports wrap ISBNs as ="9780356518657"; an empty value means none.
    static func cleanISBN(_ value: String?) -> String? {
        let digits = (value ?? "").filter { $0.isNumber || $0 == "X" }
        return digits.isEmpty ? nil : digits
    }
}

/// Works out reading spans for past books, which Goodreads only gives a finish date.
///
/// Rules (see SPEC.md): sort dated reads by finish date; a book's start is the
/// previous book's finish date, but never more than 30 days before its own finish.
nonisolated enum BackfillPlanner {
    struct Span: Equatable {
        var start: Date
        var finish: Date?
    }

    static let maxEstimatedDays = 30

    static func spans(for rows: [GoodreadsRow], today: Date, calendar: Calendar = .current) -> [String: Span] {
        let finishedDates = rows
            .filter { $0.shelf == GoodreadsRow.readShelf }
            .compactMap(\.dateRead)
        let distinctFinishes = Set(finishedDates).sorted()

        func estimatedStart(endingAt end: Date) -> Date {
            let cap = calendar.date(byAdding: .day, value: -maxEstimatedDays, to: end) ?? end
            // Latest finish strictly before this one, so books finished on the
            // same day share the same start.
            guard let previous = distinctFinishes.last(where: { $0 < end }) else { return cap }
            return max(previous, cap)
        }

        var result: [String: Span] = [:]
        for row in rows {
            switch row.shelf {
            case GoodreadsRow.readShelf:
                guard let finish = row.dateRead else { continue }
                result[row.goodreadsID] = Span(start: estimatedStart(endingAt: finish), finish: finish)
            case GoodreadsRow.currentlyReadingShelf:
                let todayStart = calendar.startOfDay(for: today)
                result[row.goodreadsID] = Span(start: estimatedStart(endingAt: todayStart), finish: nil)
            default:
                continue  // DNF books have no dates in the export: library only.
            }
        }
        return result
    }
}

struct ImportSummary: Equatable {
    var booksAdded = 0
    var booksUpdated = 0
    var readingsAdded = 0
    var quotesAdded = 0
}

enum GoodreadsImporter {
    /// Imports or re-imports an export. Safe to run repeatedly: books are matched
    /// by Goodreads ID, existing quotes are kept, and hand-edited dates are never touched.
    static func importCSV(_ text: String, into context: ModelContext, today: Date = .now) throws -> ImportSummary {
        let rows = GoodreadsCSV.rows(fromCSV: text).filter(\.isIncluded)
        let spans = BackfillPlanner.spans(for: rows, today: today)

        let existingBooks = try context.fetch(FetchDescriptor<Book>())
        var booksByID: [String: Book] = [:]
        for book in existingBooks {
            if let id = book.goodreadsID { booksByID[id] = book }
        }

        var summary = ImportSummary()
        for row in rows {
            let book: Book
            if let existing = booksByID[row.goodreadsID] {
                book = existing
                summary.booksUpdated += 1
            } else {
                book = Book(title: row.title, author: row.author)
                book.goodreadsID = row.goodreadsID
                context.insert(book)
                booksByID[row.goodreadsID] = book
                summary.booksAdded += 1
            }

            book.title = row.title
            book.author = row.author
            book.isbn13 = row.isbn13 ?? book.isbn13
            book.pageCount = row.pageCount ?? book.pageCount
            book.rating = row.rating
            book.status = row.status

            if let span = spans[row.goodreadsID] {
                if applySpan(span, status: row.status, to: book, in: context) {
                    summary.readingsAdded += 1
                }
            }

            let existingTexts = Set((book.quotes ?? []).map(\.text))
            for text in QuoteExtractor.quotes(fromReview: row.review) where !existingTexts.contains(text) {
                context.insert(Quote(book: book, text: text, source: .goodreadsCSV))
                summary.quotesAdded += 1
            }
        }

        try context.save()
        return summary
    }

    /// Creates or updates the CSV-sourced reading. Returns true when a new one was added.
    private static func applySpan(_ span: BackfillPlanner.Span, status: BookStatus,
                                  to book: Book, in context: ModelContext) -> Bool {
        let readings = book.readings ?? []
        if let existing = readings.first(where: { $0.source == .goodreadsCSV }) {
            guard !existing.datesEditedManually else { return false }
            existing.startedAt = span.start
            existing.finishedAt = span.finish
            existing.outcome = span.finish == nil ? nil : status
            return false
        }
        // Another source (RSS or manual) already tracks this book.
        guard readings.isEmpty else { return false }

        let reading = Reading(book: book, startedAt: span.start, finishedAt: span.finish, source: .goodreadsCSV)
        reading.startIsEstimated = true
        reading.outcome = span.finish == nil ? nil : status
        context.insert(reading)
        return true
    }
}

nonisolated extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
