//
//  GoodreadsFeed.swift
//  Amaris
//
//  Reads a user's public Goodreads shelf RSS feeds:
//  goodreads.com/review/list_rss/{userID}?shelf={shelf}&page={n}
//
//  Notes on the feed (checked against a real account):
//  - 100 items per page.
//  - `user_date_added` on currently-reading = when the book was shelved there → start date.
//  - `user_read_at` on read = the "date read" → finish date (midnight UTC).
//  - `user_rating` is rounded to whole stars, so it must not overwrite a precise rating.
//  - `book_large_image_url` has a size suffix (._SY475_); removing it gives the original.
//

import Foundation

nonisolated struct FeedItem: Equatable {
    var bookID: String
    var title: String
    var author: String
    var imageURL: URL?
    var readAt: Date?
    var dateAdded: Date?
    var rating: Int?
    var pageCount: Int?
}

nonisolated enum Shelf: String, CaseIterable {
    case currentlyReading = "currently-reading"
    case read
    case didNotFinish = "did-not-finish"
}

nonisolated enum GoodreadsFeed {
    static let pageSize = 100

    /// Accepts a profile link ("goodreads.com/user/show/123-name") or a bare ID.
    static func userID(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = trimmed.firstMatch(of: /user\/show\/(\d+)/) { return String(match.1) }
        if let match = trimmed.wholeMatch(of: /\d+/) { return String(match.0) }
        return nil
    }

    static func url(userID: String, shelf: Shelf, page: Int) -> URL {
        var components = URLComponents(string: "https://www.goodreads.com/review/list_rss/\(userID)")!
        components.queryItems = [
            URLQueryItem(name: "shelf", value: shelf.rawValue),
            URLQueryItem(name: "page", value: String(page)),
        ]
        return components.url!
    }

    /// Fetches every page of a shelf.
    static func fetchShelf(_ shelf: Shelf, userID: String, session: URLSession) async throws -> [FeedItem] {
        var all: [FeedItem] = []
        for page in 1...20 {
            let (data, response) = try await session.data(from: url(userID: userID, shelf: shelf, page: page))
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let items = parse(data)
            all += items
            if items.count < pageSize { break }
        }
        return all
    }

    // MARK: - Parsing

    static func parse(_ data: Data) -> [FeedItem] {
        let delegate = ItemCollector()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items.compactMap(item(from:))
    }

    static func item(from fields: [String: String]) -> FeedItem? {
        guard let id = fields["book_id"]?.trimmed, !id.isEmpty else { return nil }
        return FeedItem(
            bookID: id,
            title: GoodreadsCSV.cleanText(fields["title"] ?? ""),
            author: GoodreadsCSV.cleanText(fields["author_name"] ?? ""),
            imageURL: fields["book_large_image_url"].flatMap(fullSizeImageURL),
            readAt: fields["user_read_at"].flatMap(calendarDay),
            dateAdded: fields["user_date_added"].flatMap(rfc822),
            rating: fields["user_rating"].flatMap { Int($0.trimmed) }.flatMap { $0 > 0 ? $0 : nil },
            pageCount: fields["num_pages"].flatMap { Int($0.trimmed) }
        )
    }

    /// Removes the size suffix to get the original image. Nil for Goodreads' "no photo" placeholder.
    static func fullSizeImageURL(_ text: String) -> URL? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty, !trimmed.contains("nophoto") else { return nil }
        return URL(string: trimmed.replacing(/\._S[XY]\d+_/, with: ""))
    }

    static func rfc822(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: text.trimmed)
    }

    /// "Date read" is a calendar day stored as midnight UTC. Keep the same
    /// day number in local time, so the 3rd stays the 3rd.
    static func calendarDay(_ text: String) -> Date? {
        guard let instant = rfc822(text) else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let parts = utc.dateComponents([.year, .month, .day], from: instant)
        return Calendar.current.date(from: parts)
    }
}

/// Collects each <item>'s child elements as a flat [name: text] dictionary.
nonisolated private final class ItemCollector: NSObject, XMLParserDelegate {
    var items: [[String: String]] = []
    private var current: [String: String]?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if name == "item" { current = [:] }
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        text += String(decoding: block, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "item", let item = current {
            items.append(item)
            current = nil
        } else if current != nil, current?[name] == nil {
            current?[name] = text
        }
        text = ""
    }
}
