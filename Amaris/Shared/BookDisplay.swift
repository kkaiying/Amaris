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

    /// For "recently read" sorting: books being read come first.
    var recencyDate: Date {
        guard let latest = latestReading else { return .distantPast }
        return latest.finishedAt ?? .distantFuture
    }
}
