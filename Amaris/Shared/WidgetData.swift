//
//  WidgetData.swift
//  Amaris
//
//  Plain snapshots of the database for the widgets. Widget timelines hold
//  these value types rather than SwiftData models.
//

import Foundation
import ImageIO
import SwiftData
import WidgetKit

struct BookSnapshot: Hashable, Sendable {
    var title: String
    var author: String
    var coverFileName: String?

    var displayTitle: String { BookTitle.base(title) }

    init(title: String, author: String, coverFileName: String?) {
        self.title = title
        self.author = author
        self.coverFileName = coverFileName
    }

    init(_ book: Book) {
        self.init(title: book.title, author: book.author, coverFileName: book.coverFileName)
    }
}

struct QuoteSnapshot: Hashable, Sendable {
    var text: String
    var book: BookSnapshot
    var isFavourite: Bool
}

enum WidgetData {
    static func context() -> ModelContext {
        ModelContext(AmarisStore.shared)
    }

    /// Books being read on each day of the month containing `date`.
    static func monthDays(containing date: Date, in context: ModelContext) -> [Date: [BookSnapshot]] {
        let readings = (try? context.fetch(FetchDescriptor<Reading>())) ?? []
        let month = ReadingCalendar.month(containing: date)
        return ReadingCalendar.booksByDay(readings, in: month, today: date).mapValues { $0.map(BookSnapshot.init) }
    }

    /// The book started most recently that's still being read (not on hold),
    /// when it was started, and how many days it has actually been read.
    static func currentBook(in context: ModelContext, today: Date = .now) -> (book: BookSnapshot, startedAt: Date, daysRead: Int)? {
        let readings = (try? context.fetch(FetchDescriptor<Reading>())) ?? []
        let open = readings
            .filter { $0.finishedAt == nil && !$0.isPaused && $0.book?.status == .reading }
            .compactMap { reading -> (Reading, Book, Date)? in
                guard let book = reading.book, let start = reading.startedAt else { return nil }
                return (reading, book, start)
            }
            .max { $0.2 < $1.2 }
        return open.map { (BookSnapshot($0.1), $0.2, $0.0.daysRead(through: today)) }
    }

    /// Books finished in the year containing `date` (not DNF), most recent first.
    static func finishedThisYear(containing date: Date, in context: ModelContext) -> [BookSnapshot] {
        let year = ReadingCalendar.year(containing: date)
        let readings = (try? context.fetch(FetchDescriptor<Reading>())) ?? []
        return readings
            .filter { reading in
                guard let finished = reading.finishedAt, reading.outcome != .dnf else { return false }
                return year.contains(finished)
            }
            .sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
            .compactMap { $0.book.map(BookSnapshot.init) }
    }

    /// With "Hide low-rated books" on, quotes from books rated below this are
    /// skipped. Unrated books still show.
    static let lowRatingCutoff = 3.5

    static func quotes(favouritesOnly: Bool, hideLowRated: Bool = false, in context: ModelContext) -> [QuoteSnapshot] {
        let quotes = (try? context.fetch(FetchDescriptor<Quote>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return quotes
            .filter { !favouritesOnly || $0.isFavourite }
            .filter { !hideLowRated || ($0.book?.rating ?? lowRatingCutoff) >= lowRatingCutoff }
            .compactMap { quote in
                quote.book.map { QuoteSnapshot(text: quote.text, book: BookSnapshot($0), isFavourite: quote.isFavourite) }
            }
    }

    /// Asks every widget to redraw with fresh data (after a sync or an edit).
    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Which quote the quote widget shows. Quotes rotate every hour in a shuffled
/// (but stable) order; the widget's "next" button moves one step ahead.
enum QuoteRotation {
    static let rotationInterval: TimeInterval = 60 * 60
    private static let offsetKey = "quoteRotationOffset"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AmarisStore.appGroupID) ?? .standard
    }

    static var offset: Int {
        get { defaults.integer(forKey: offsetKey) }
        set { defaults.set(newValue, forKey: offsetKey) }
    }

    static func advance() { offset += 1 }

    /// The quote to show at `date`.
    static func quote(at date: Date, from quotes: [QuoteSnapshot]) -> QuoteSnapshot? {
        guard !quotes.isEmpty else { return nil }
        let order = shuffledOrder(count: quotes.count)
        let slot = Int(date.timeIntervalSinceReferenceDate / rotationInterval) + offset
        return quotes[order[((slot % order.count) + order.count) % order.count]]
    }

    /// The start of the hour after `date`, when the next quote appears.
    static func nextChange(after date: Date) -> Date {
        let slot = (date.timeIntervalSinceReferenceDate / rotationInterval).rounded(.down) + 1
        return Date(timeIntervalSinceReferenceDate: slot * rotationInterval)
    }

    /// A fixed pseudo-random order, so consecutive quotes jump between books
    /// but the sequence doesn't change between widget reloads.
    static func shuffledOrder(count: Int) -> [Int] {
        var generator = SplitMix64(seed: 0xA3A215)
        var order = Array(0..<count)
        for i in stride(from: count - 1, to: 0, by: -1) {
            let j = Int(generator.next() % UInt64(i + 1))
            order.swapAt(i, j)
        }
        return order
    }
}

struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Fan art shown faintly behind the quote widget, one image per theme.
/// Stored in the App Group container (never in the repo: it's the artists' work).
enum FanArtStore {
    static var directory: URL {
        let url = AmarisStore.sharedContainerURL.appending(path: "FanArt", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(for theme: AmarisTheme) -> URL {
        directory.appending(path: "\(theme.rawValue).jpg")
    }

    static func hasImage(for theme: AmarisTheme) -> Bool {
        FileManager.default.fileExists(atPath: url(for: theme).path(percentEncoded: false))
    }

    static func save(_ data: Data, for theme: AmarisTheme) throws {
        guard let jpeg = CoverStore.normalizedJPEG(data) else { throw CocoaError(.fileReadCorruptFile) }
        try jpeg.write(to: url(for: theme), options: .atomic)
    }

    static func remove(for theme: AmarisTheme) {
        try? FileManager.default.removeItem(at: url(for: theme))
    }

    static func image(for theme: AmarisTheme) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: theme) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
