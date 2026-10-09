//
//  ShelfPageImport.swift
//  Amaris
//
//  One-time fix for start dates. The Goodreads CSV export has no "date
//  started", but the signed-in shelf page (table view with the "date started"
//  column) does. Save that page as HTML and import it here.
//
//  Each row has editable date fields like:
//    reviewEditor.summon(this, 127280062, 'started_at', {value: &quot;2026-10-03&quot;, …
//  in the same order as the row's reading sessions.
//

import Foundation
import SwiftData

nonisolated enum GoodreadsShelfPage {
    struct Session: Equatable {
        var started: Date?
        var finished: Date?
    }

    /// Reading sessions per Goodreads book ID.
    static func sessions(fromHTML html: String) -> [String: [Session]] {
        let rowPattern = /<tr id="review_\d+"(?s:.*?)<\/tr>/
        let datePattern = /reviewEditor\.summon\(this, (\d+), '(started_at|read_at)', \{value: &quot;([\d-]*)&quot;/

        var result: [String: [Session]] = [:]
        for row in html.matches(of: rowPattern) {
            var bookID: String?
            var starts: [Date?] = []
            var finishes: [Date?] = []
            for match in row.output.matches(of: datePattern) {
                bookID = bookID ?? String(match.1)
                let date = parseDay(String(match.3))
                if match.2 == "started_at" { starts.append(date) } else { finishes.append(date) }
            }
            guard let bookID else { continue }

            var sessions: [Session] = []
            for index in 0..<max(starts.count, finishes.count) {
                let session = Session(started: index < starts.count ? starts[index] : nil,
                                      finished: index < finishes.count ? finishes[index] : nil)
                // The page can repeat a session in its markup.
                if (session.started != nil || session.finished != nil), !sessions.contains(session) {
                    sessions.append(session)
                }
            }
            if !sessions.isEmpty { result[bookID, default: []] += sessions }
        }
        return result
    }

    /// "2026-10-03" → start of that local day.
    static func parseDay(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

struct StartDateSummary: Equatable {
    var updated = 0
    var alreadyCorrect = 0
    var keptManualEdits = 0
}

enum StartDateImporter {
    /// Replaces start dates with the real ones from the shelf page. Only
    /// touches readings' start dates; skips anything edited by hand.
    static func apply(_ sessionsByBook: [String: [GoodreadsShelfPage.Session]],
                      to context: ModelContext) throws -> StartDateSummary {
        var summary = StartDateSummary()
        for book in try context.fetch(FetchDescriptor<Book>()) {
            guard let id = book.goodreadsID, let sessions = sessionsByBook[id] else { continue }

            for reading in book.readings ?? [] {
                guard let session = matchingSession(for: reading, in: sessions),
                      let started = session.started else { continue }
                if reading.datesEditedManually {
                    summary.keptManualEdits += 1
                    continue
                }
                if let finished = reading.finishedAt, started > finished { continue }

                if reading.startedAt == started {
                    summary.alreadyCorrect += 1
                } else {
                    reading.startedAt = started
                    summary.updated += 1
                }
                reading.startIsEstimated = false
            }
        }
        try context.save()
        return summary
    }

    /// The session that finished on the same day as this reading (or the open
    /// session for a reading in progress). Falls back to a book's only session.
    private static func matchingSession(for reading: Reading,
                                        in sessions: [GoodreadsShelfPage.Session]) -> GoodreadsShelfPage.Session? {
        if let match = sessions.first(where: { $0.finished == reading.finishedAt }) {
            return match
        }
        return sessions.count == 1 ? sessions[0] : nil
    }
}
