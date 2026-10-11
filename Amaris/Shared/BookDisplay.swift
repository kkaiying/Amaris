//
//  BookDisplay.swift
//  Amaris
//
//  Display helpers shared by the app and widgets.
//

import Foundation

nonisolated enum BookTitle {
    /// "Crooked Kingdom (Six of Crows, #2)" → "Crooked Kingdom"
    static func base(_ title: String) -> String {
        title.replacing(/\s*\([^()]*#[^()]*\)\s*$/, with: "")
    }

    /// "Crooked Kingdom (Six of Crows, #2)" → "Six of Crows #2"
    static func series(_ title: String) -> String? {
        guard let match = title.firstMatch(of: /\(([^()]*?),?\s*#([^()]*)\)\s*$/) else { return nil }
        return "\(match.1) #\(match.2)"
    }
}

extension Book {
    var displayTitle: String { BookTitle.base(title) }
    var series: String? { BookTitle.series(title) }

    /// The reading still in progress, if any.
    var openReading: Reading? {
        (readings ?? []).first { $0.finishedAt == nil }
    }

    /// The most recent read-through.
    var latestReading: Reading? {
        (readings ?? []).max { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) }
    }

    /// On hold: still on currently-reading, but not being read for now.
    var isPaused: Bool { openReading?.isPaused ?? false }

    /// For "recently read" sorting: books being read come first.
    var recencyDate: Date {
        guard let latest = latestReading else { return .distantPast }
        return latest.finishedAt ?? .distantFuture
    }
}

extension Reading {
    /// Still open and currently on hold.
    var isPaused: Bool { finishedAt == nil && pauses.contains { $0.end == nil } }

    /// Puts the reading on hold from `day` (the first day not read).
    func pause(on day: Date) {
        guard !pauses.contains(where: { $0.end == nil }) else { return }
        let start = max(Calendar.current.startOfDay(for: day), startedAt ?? .distantPast)
        pauses.append(ReadingPause(start: start))
    }

    /// Ends the hold; `day` is the first day read again.
    func resume(on day: Date) {
        guard let index = pauses.firstIndex(where: { $0.end == nil }) else { return }
        pauses[index].end = max(Calendar.current.startOfDay(for: day), pauses[index].start)
    }

    /// Whether `day` falls inside a pause. A hold left open when the book was
    /// finished ends there, so the finish day still shows.
    func isPaused(on day: Date) -> Bool {
        pauses.contains { pause in
            guard pause.start <= day else { return false }
            guard let end = pause.end ?? finishedAt else { return true }
            return day < end
        }
    }

    /// Days actually spent reading from the start through `today` (1 on the first day).
    func daysRead(through today: Date, calendar: Calendar = .current) -> Int {
        guard let startedAt else { return 0 }
        var count = 0
        var day = calendar.startOfDay(for: startedAt)
        let last = calendar.startOfDay(for: finishedAt ?? today)
        while day <= last {
            if !isPaused(on: day) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }
}
