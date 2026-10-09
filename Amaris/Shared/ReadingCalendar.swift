//
//  ReadingCalendar.swift
//  Amaris
//
//  Works out which books I was reading on each day. Shared by the app's year
//  view and the calendar widget.
//
//  A book fills every day from its start date to its finish date (inclusive);
//  a book still being read fills through today.
//

import Foundation

enum ReadingCalendar {
    /// Books being read on each day within `interval`, keyed by start of day,
    /// earliest-started book first.
    static func booksByDay(_ readings: [Reading], in interval: DateInterval,
                           today: Date = .now, calendar: Calendar = .current) -> [Date: [Book]] {
        let todayStart = calendar.startOfDay(for: today)
        var result: [Date: [(start: Date, book: Book)]] = [:]

        for reading in readings {
            guard let book = reading.book, let startedAt = reading.startedAt else { continue }
            let start = calendar.startOfDay(for: startedAt)
            let end = calendar.startOfDay(for: reading.finishedAt ?? todayStart)
            guard start <= end else { continue }

            var day = max(start, calendar.startOfDay(for: interval.start))
            let last = min(end, interval.end)
            while day <= last, day < interval.end {
                result[day, default: []].append((start, book))
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        return result.mapValues { entries in
            var seen = Set<ObjectIdentifier>()
            return entries
                .sorted { $0.start < $1.start }
                .map(\.book)
                .filter { seen.insert(ObjectIdentifier($0)).inserted }
        }
    }

    static func year(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .year, for: date)!
    }

    static func month(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)!
    }
}
