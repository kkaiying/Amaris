//
//  AmarisTests.swift
//  AmarisTests
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import Foundation
import SwiftData
import Testing
@testable import Amaris

private func day(_ text: String) -> Date {
    GoodreadsCSV.parseDate(text)!
}

private func row(_ id: String, shelf: String = "read", dateRead: String? = nil, review: String = "") -> GoodreadsRow {
    GoodreadsRow(goodreadsID: id, title: "Book \(id)", author: "Author", isbn13: nil, rating: nil,
                 pageCount: nil, dateRead: dateRead.map(day), shelf: shelf, review: review)
}

struct CSVParserTests {
    @Test func handlesQuotedCommasEscapedQuotesAndNewlines() {
        let csv = "a,b,c\n1,\"x, y\",\"she said \"\"hi\"\"\nnext line\"\n2,plain,last"
        let rows = CSVParser.parse(csv)
        #expect(rows == [
            ["a", "b", "c"],
            ["1", "x, y", "she said \"hi\"\nnext line"],
            ["2", "plain", "last"],
        ])
    }

    @Test func handlesWindowsLineEndingsAndByteOrderMark() {
        let rows = CSVParser.parseWithHeader("\u{FEFF}Book Id,Title\r\n42,Dune\r\n")
        #expect(rows == [["Book Id": "42", "Title": "Dune"]])
    }
}

struct QuoteExtractorTests {
    @Test func italicBoldWithEitherClosingOrder() {
        #expect(QuoteExtractor.quotes(fromReview: "<i><b>First.</i></b><br/><br/>4 ⭐ review") == ["First."])
        #expect(QuoteExtractor.quotes(fromReview: "<i><b>Second.</b></i><br/><br/>review") == ["Second."])
    }

    @Test func plainItalics() {
        #expect(QuoteExtractor.quotes(fromReview: "<i>Just italic.</i> then the review") == ["Just italic."])
    }

    @Test func multipleQuotesSeparatedByLineBreaks() {
        let review = "<i><b>“One.”<br/><br/>“Two.”<br />“Three.”</b></i><br/><br/>my thoughts"
        #expect(QuoteExtractor.quotes(fromReview: review) == ["“One.”", "“Two.”", "“Three.”"])
    }

    @Test func multipleSeparateItalicBlocks() {
        let review = "<i><b>One.</b></i><br/><br/><i><b>Two.</b></i><br/><br/>review"
        #expect(QuoteExtractor.quotes(fromReview: review) == ["One.", "Two."])
    }

    @Test func reviewWithoutQuotes() {
        #expect(QuoteExtractor.quotes(fromReview: "3.5 ⭐ a solid read!").isEmpty)
        #expect(QuoteExtractor.quotes(fromReview: "").isEmpty)
    }

    @Test func decodesEntities() {
        #expect(QuoteExtractor.quotes(fromReview: "<i>Tom &amp; Jerry &quot;ok&quot; &#8220;x&#8221;</i>")
                == ["Tom & Jerry \"ok\" “x”"])
    }
}

struct GoodreadsCSVTests {
    @Test func cleansTitlesAndISBNs() {
        #expect(GoodreadsCSV.cleanText("The \u{200B}Mirror  (Series, #3)") == "The Mirror (Series, #3)")
        #expect(GoodreadsCSV.cleanText("Sara  Hashem") == "Sara Hashem")
        #expect(GoodreadsCSV.cleanISBN("=\"9780356518657\"") == "9780356518657")
        #expect(GoodreadsCSV.cleanISBN("=\"\"") == nil)
    }

    @Test func parsesRatingsWithQuarterStarsAndUnrated() {
        let base = ["Book Id": "1", "Exclusive Shelf": "read"]
        #expect(GoodreadsCSV.row(from: base.merging(["My Rating": "3.75"]) { $1 })?.rating == 3.75)
        #expect(GoodreadsCSV.row(from: base.merging(["My Rating": "0"]) { $1 })?.rating == nil)
    }

    @Test func includesOnlyDatedReadsCurrentAndDNF() {
        #expect(row("1", dateRead: "2026/01/01").isIncluded)
        #expect(!row("2").isIncluded)                       // old read, no date
        #expect(row("3", shelf: "currently-reading").isIncluded)
        #expect(row("4", shelf: "did-not-finish").isIncluded)
        #expect(!row("5", shelf: "to-read").isIncluded)
    }
}

struct BackfillPlannerTests {
    let today = day("2026/10/09")

    @Test func startIsPreviousBooksFinish() {
        let spans = BackfillPlanner.spans(for: [
            row("b", dateRead: "2026/03/10"),
            row("a", dateRead: "2026/03/01"),   // CSV order doesn't matter
        ], today: today)
        #expect(spans["b"] == .init(start: day("2026/03/01"), finish: day("2026/03/10")))
    }

    @Test func startIsCappedAtThirtyDays() {
        let spans = BackfillPlanner.spans(for: [
            row("a", dateRead: "2025/06/01"),
            row("b", dateRead: "2026/03/10"),
        ], today: today)
        #expect(spans["b"]?.start == day("2026/02/08"))
        // The first book has no predecessor, so it gets the cap too.
        #expect(spans["a"]?.start == day("2025/05/02"))
    }

    @Test func booksFinishedSameDayShareStart() {
        let spans = BackfillPlanner.spans(for: [
            row("a", dateRead: "2026/08/20"),
            row("b", dateRead: "2026/08/29"),
            row("c", dateRead: "2026/08/29"),
        ], today: today)
        #expect(spans["b"]?.start == day("2026/08/20"))
        #expect(spans["c"]?.start == day("2026/08/20"))
    }

    @Test func currentlyReadingRunsFromLastFinishWithNoEnd() {
        let spans = BackfillPlanner.spans(for: [
            row("a", dateRead: "2026/10/05"),
            row("now", shelf: "currently-reading"),
        ], today: today)
        #expect(spans["now"] == .init(start: day("2026/10/05"), finish: nil))
    }

    @Test func dnfGetsNoSpan() {
        let spans = BackfillPlanner.spans(for: [row("x", shelf: "did-not-finish")], today: today)
        #expect(spans["x"] == nil)
    }
}

@MainActor
struct GoodreadsImporterTests {
    let csv = """
    Book Id,Title,Author,ISBN13,My Rating,Number of Pages,Date Read,Exclusive Shelf,My Review
    1,First Book,A. Author,9780000000001,4.5,300,2026/09/01,read,"<i><b>Quote one.<br/><br/>Quote two.</b></i><br/><br/>Loved it, truly."
    2,Second Book,B. Author,,0,,2026/09/20,read,
    3,Old Read,C. Author,,5,,,read,
    4,Abandoned,D. Author,,0,,,did-not-finish,
    5,Wishlist,E. Author,,0,,,to-read,
    """

    @Test func importsBooksReadingsAndQuotes() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let summary = try GoodreadsImporter.importCSV(csv, into: context, today: day("2026/10/09"))

        #expect(summary == ImportSummary(booksAdded: 3, booksUpdated: 0, readingsAdded: 2, quotesAdded: 2))
        let second = try context.fetch(FetchDescriptor<Book>()).first { $0.goodreadsID == "2" }
        #expect(second?.readings?.first?.startedAt == day("2026/09/01"))
        #expect(second?.rating == nil)
    }

    @Test func reimportDoesNotDuplicateOrOverwriteEdits() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        _ = try GoodreadsImporter.importCSV(csv, into: context, today: day("2026/10/09"))

        let first = try context.fetch(FetchDescriptor<Book>()).first { $0.goodreadsID == "1" }!
        let reading = first.readings!.first!
        reading.startedAt = day("2026/08/15")
        reading.datesEditedManually = true

        let summary = try GoodreadsImporter.importCSV(csv, into: context, today: day("2026/10/09"))
        #expect(summary == ImportSummary(booksAdded: 0, booksUpdated: 3, readingsAdded: 0, quotesAdded: 0))
        #expect(try context.fetchCount(FetchDescriptor<Quote>()) == 2)
        #expect(reading.startedAt == day("2026/08/15"))
    }
}

struct CoverFetcherTests {
    @Test func baseTitleStripsSeries() {
        #expect(CoverFetcher.baseTitle("Crooked Kingdom (Six of Crows, #2)") == "Crooked Kingdom")
        #expect(CoverFetcher.baseTitle("Alchemised") == "Alchemised")
    }
}

struct GoodreadsFeedTests {
    let xml = """
    <?xml version="1.0"?>
    <rss><channel><title>Shelf</title>
    <item>
      <title><![CDATA[Some Book (Series, #1)]]></title>
      <book_id>123</book_id>
      <book_large_image_url><![CDATA[https://i.gr-assets.com/books/1639888350l/123._SY475_.jpg]]></book_large_image_url>
      <author_name>Some  Author</author_name>
      <user_rating>3</user_rating>
      <user_read_at><![CDATA[Sat, 3 Oct 2026 00:00:00 +0000]]></user_read_at>
      <user_date_added><![CDATA[Mon, 05 Oct 2026 13:01:53 -0700]]></user_date_added>
      <book id="123"><num_pages>449</num_pages></book>
    </item>
    <item>
      <title>No Photo</title><book_id>456</book_id>
      <book_large_image_url>https://s.gr-assets.com/assets/nophoto/book/111x148.png</book_large_image_url>
      <user_rating>0</user_rating><user_read_at></user_read_at>
    </item>
    </channel></rss>
    """

    @Test func parsesItems() throws {
        let items = GoodreadsFeed.parse(Data(xml.utf8))
        #expect(items.count == 2)
        let first = try #require(items.first)
        #expect(first.bookID == "123")
        #expect(first.title == "Some Book (Series, #1)")
        #expect(first.author == "Some Author")
        #expect(first.imageURL?.absoluteString == "https://i.gr-assets.com/books/1639888350l/123.jpg")
        #expect(first.readAt == day("2026/10/03"))
        #expect(first.rating == 3)
        #expect(first.pageCount == 449)

        #expect(items[1].imageURL == nil)   // "nophoto" placeholder
        #expect(items[1].rating == nil)
        #expect(items[1].readAt == nil)
    }

    @Test func readsUserIDFromProfileLink() {
        #expect(GoodreadsFeed.userID(from: "https://www.goodreads.com/user/show/156605841-lin") == "156605841")
        #expect(GoodreadsFeed.userID(from: " 156605841 ") == "156605841")
        #expect(GoodreadsFeed.userID(from: "not a link") == nil)
    }
}

@MainActor
struct FeedApplierTests {
    func item(_ id: String, readAt: String? = nil, added: Date? = nil, rating: Int? = nil) -> FeedItem {
        FeedItem(bookID: id, title: "Book \(id)", author: "Author", imageURL: URL(string: "https://example.com/\(id).jpg"),
                 readAt: readAt.map(day), dateAdded: added, rating: rating, pageCount: nil)
    }

    func apply(_ items: [FeedItem], _ shelf: Shelf, _ context: ModelContext) throws -> SyncSummary {
        var summary = SyncSummary()
        _ = try FeedApplier.apply(items, shelf: shelf, to: context, summary: &summary)
        try context.save()
        return summary
    }

    func book(_ id: String, _ context: ModelContext) throws -> Book {
        try #require(try context.fetch(FetchDescriptor<Book>()).first { $0.goodreadsID == id })
    }

    @Test func startingThenFinishingABook() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let started = try apply([item("1", added: day("2026/10/10").addingTimeInterval(3600 * 13))], .currentlyReading, context)
        #expect(started.started == 1)
        let reading = try #require(try book("1", context).readings?.first)
        #expect(reading.startedAt == day("2026/10/10"))
        #expect(reading.finishedAt == nil)

        let finished = try apply([item("1", readAt: "2026/10/14")], .read, context)
        #expect(finished.finished == 1)
        #expect(reading.finishedAt == day("2026/10/14"))
        #expect(try book("1", context).status == .read)
        #expect(try book("1", context).readings?.count == 1)
    }

    @Test func dnfClosesOpenReading() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        _ = try apply([item("1", added: day("2026/10/01"))], .currentlyReading, context)
        let summary = try apply([item("1", added: day("2026/10/04"))], .didNotFinish, context)
        #expect(summary.dnf == 1)
        let reading = try #require(try book("1", context).readings?.first)
        #expect(reading.finishedAt == day("2026/10/04"))
        #expect(reading.outcome == .dnf)
    }

    @Test func roundedFeedRatingNeverReplacesPreciseRating() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        _ = try apply([item("1", readAt: "2026/10/03", rating: 4)], .read, context)
        #expect(try book("1", context).rating == 4)
        try book("1", context).rating = 3.5
        _ = try apply([item("1", readAt: "2026/10/03", rating: 3)], .read, context)
        #expect(try book("1", context).rating == 3.5)
    }

    @Test func undatedReadsAreSkipped() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        _ = try apply([item("old")], .read, context)
        #expect(try context.fetchCount(FetchDescriptor<Book>()) == 0)
    }

    @Test func handEditedDatesAreKept() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        _ = try apply([item("1", added: day("2026/10/01"))], .currentlyReading, context)
        let reading = try #require(try book("1", context).readings?.first)
        reading.datesEditedManually = true
        _ = try apply([item("1", readAt: "2026/10/09")], .read, context)
        #expect(reading.finishedAt == nil)
    }

    @Test func manualCoversAreNeverReplaced() throws {
        let book = Book(title: "x", author: "y")
        book.coverSource = .manual
        #expect(!FeedApplier.wantsGoodreadsCover(book))
        book.coverSource = .openLibrary
        #expect(FeedApplier.wantsGoodreadsCover(book))
    }
}

@MainActor
struct CoverStoreTests {
    /// Regression: the App Group path contains a space ("Group Containers"),
    /// which a percent-encoded path check treated as missing.
    @Test func detectsSavedCoverInSharedContainer() throws {
        let book = Book(title: "Test", author: "Test")
        book.goodreadsID = "test-\(UUID().uuidString)"
        #expect(AmarisStore.coversDirectory.path(percentEncoded: false).contains(" "))
        #expect(!CoverStore.hasCover(for: book))

        let pixel = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="))
        try CoverStore.save(pixel, for: book, source: .goodreads)
        defer { try? FileManager.default.removeItem(at: CoverStore.url(for: book)!) }

        #expect(CoverStore.hasCover(for: book))
        #expect(book.coverSource == .goodreads)
        #expect(!FeedApplier.wantsGoodreadsCover(book))   // no re-download
    }
}

struct BookTitleTests {
    @Test func splitsTitleAndSeries() {
        #expect(BookTitle.base("Crooked Kingdom (Six of Crows, #2)") == "Crooked Kingdom")
        #expect(BookTitle.series("Crooked Kingdom (Six of Crows, #2)") == "Six of Crows #2")
        #expect(BookTitle.series("The Assassin's Blade (Throne of Glass, #0.1-0.5)") == "Throne of Glass #0.1-0.5")
        #expect(BookTitle.base("Alchemised") == "Alchemised")
        #expect(BookTitle.series("Alchemised") == nil)
    }
}

@MainActor
struct ShelfChangeTests {
    func item(_ id: String, readAt: String? = nil, added: Date? = nil) -> FeedItem {
        FeedItem(bookID: id, title: "Book \(id)", author: "Author", imageURL: nil,
                 readAt: readAt.map(day), dateAdded: added, rating: nil, pageCount: nil)
    }

    func sync(_ items: [FeedItem], _ shelf: Shelf, _ context: ModelContext) throws {
        var summary = SyncSummary()
        _ = try FeedApplier.apply(items, shelf: shelf, to: context, summary: &summary)
    }

    @Test func dnfMarkedInAppSurvivesSyncWhileShelfUnchanged() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        try sync([item("1", added: day("2026/10/01"))], .currentlyReading, context)
        let book = try #require(try context.fetch(FetchDescriptor<Book>()).first)

        // Marked DNF in the app; Goodreads still says currently-reading.
        let reading = try #require(book.openReading)
        reading.finishedAt = day("2026/10/05")
        reading.outcome = .dnf
        reading.datesEditedManually = true
        book.status = .dnf

        try sync([item("1", added: day("2026/10/01"))], .currentlyReading, context)
        #expect(book.status == .dnf)
        #expect(book.readings?.count == 1)          // no new reading started
        #expect(reading.finishedAt == day("2026/10/05"))
    }

    @Test func movingShelfOnGoodreadsStillApplies() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        try sync([item("1", added: day("2026/10/01"))], .currentlyReading, context)
        let book = try #require(try context.fetch(FetchDescriptor<Book>()).first)
        book.status = .dnf                           // app edit…

        try sync([item("1", readAt: "2026/10/08")], .read, context)
        #expect(book.status == .read)                // …but finishing on Goodreads wins
        #expect(book.latestReading?.finishedAt == day("2026/10/08"))
    }
}

struct PastedQuotesTests {
    @Test func blankLinesSeparateQuotes() {
        let pasted = "“First quote.”\n\n“Second quote,\nsame quote, new line.”\n \n\n\nThird.\r\n\r\nFourth."
        #expect(QuoteExtractor.quotes(fromPastedText: pasted) == [
            "“First quote.”",
            "“Second quote,\nsame quote, new line.”",
            "Third.",
            "Fourth.",
        ])
    }

    @Test func emptyPasteGivesNoQuotes() {
        #expect(QuoteExtractor.quotes(fromPastedText: "  \n\n ").isEmpty)
    }
}

@MainActor
struct ReadingCalendarTests {
    @Test func fillsEveryDayFromStartToFinishAndOpenReadingsThroughToday() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let first = Book(title: "First", author: "A")
        let second = Book(title: "Second", author: "B")
        context.insert(first)
        context.insert(second)
        let finished = Reading(book: first, startedAt: day("2026/10/01"), finishedAt: day("2026/10/05"), source: .manual)
        let open = Reading(book: second, startedAt: day("2026/10/05"), source: .manual)
        context.insert(finished)
        context.insert(open)

        let october = ReadingCalendar.month(containing: day("2026/10/15"))
        let days = ReadingCalendar.booksByDay([finished, open], in: october, today: day("2026/10/09"))

        #expect(days[day("2026/09/30")] == nil)
        #expect(days[day("2026/10/01")]?.map(\.title) == ["First"])
        #expect(days[day("2026/10/05")]?.map(\.title) == ["First", "Second"])   // overlap: both
        #expect(days[day("2026/10/09")]?.map(\.title) == ["Second"])            // through today
        #expect(days[day("2026/10/10")] == nil)
        #expect(days.count == 9)
    }

    @Test func clipsSpansToTheRequestedInterval() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let book = Book(title: "Long", author: "A")
        context.insert(book)
        let reading = Reading(book: book, startedAt: day("2025/12/20"), finishedAt: day("2026/01/03"), source: .manual)
        context.insert(reading)

        let days = ReadingCalendar.booksByDay([reading], in: ReadingCalendar.year(containing: day("2026/06/01")))
        #expect(days.keys.sorted() == [day("2026/01/01"), day("2026/01/02"), day("2026/01/03")])
    }
}

@MainActor
struct ShelfPageImportTests {
    // Trimmed from the real page's markup, with a duplicated session like the real one.
    let html = """
    <table><tr id="review_1" class="bookalike review">
      <td class="field date_started"><span class="date_started_value">Oct 03, 2026</span>
        <a onclick="reviewEditor.summon(this, 111, 'started_at', {value: &quot;2026-10-03&quot;, reading_session_id: &quot;x&quot;})">edit</a></td>
      <td class="field date_read"><span class="date_read_value">Oct 05, 2026</span>
        <a onclick="reviewEditor.summon(this, 111, 'read_at', {value: &quot;2026-10-05&quot;, reading_session_id: &quot;x&quot;})">edit</a></td>
    </tr>
    <tr id="review_2" class="bookalike review">
      <a onclick="reviewEditor.summon(this, 222, 'started_at', {value: &quot;2025-05-30&quot;})"></a>
      <a onclick="reviewEditor.summon(this, 222, 'started_at', {value: &quot;2025-05-30&quot;})"></a>
      <a onclick="reviewEditor.summon(this, 222, 'read_at', {value: &quot;2025-06-10&quot;})"></a>
      <a onclick="reviewEditor.summon(this, 222, 'read_at', {value: &quot;2025-06-10&quot;})"></a>
    </tr></table>
    """

    @Test func parsesSessionsPerBook() {
        let sessions = GoodreadsShelfPage.sessions(fromHTML: html)
        #expect(sessions["111"] == [.init(started: day("2026/10/03"), finished: day("2026/10/05"))])
        #expect(sessions["222"] == [.init(started: day("2025/05/30"), finished: day("2025/06/10"))])  // deduplicated
    }

    @Test func replacesEstimatesButKeepsManualEdits() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let first = Book(title: "A", author: "A"); first.goodreadsID = "111"
        let second = Book(title: "B", author: "B"); second.goodreadsID = "222"
        context.insert(first); context.insert(second)
        let estimated = Reading(book: first, startedAt: day("2026/09/30"), finishedAt: day("2026/10/05"), source: .goodreadsCSV)
        estimated.startIsEstimated = true
        let edited = Reading(book: second, startedAt: day("2025/06/01"), finishedAt: day("2025/06/10"), source: .goodreadsCSV)
        edited.datesEditedManually = true
        context.insert(estimated); context.insert(edited)

        let summary = try StartDateImporter.apply(GoodreadsShelfPage.sessions(fromHTML: html), to: context)
        #expect(summary == StartDateSummary(updated: 1, alreadyCorrect: 0, keptManualEdits: 1))
        #expect(estimated.startedAt == day("2026/10/03"))
        #expect(!estimated.startIsEstimated)
        #expect(edited.startedAt == day("2025/06/01"))
    }

    @Test func csvReimportKeepsRealStartDates() throws {
        let context = ModelContext(try AmarisStore.makeContainer(inMemory: true))
        let csv = """
        Book Id,Title,Author,ISBN13,My Rating,Number of Pages,Date Read,Exclusive Shelf,My Review
        111,A,A,,0,,2026/10/05,read,
        """
        _ = try GoodreadsImporter.importCSV(csv, into: context, today: day("2026/10/09"))
        _ = try StartDateImporter.apply(GoodreadsShelfPage.sessions(fromHTML: html), to: context)
        _ = try GoodreadsImporter.importCSV(csv, into: context, today: day("2026/10/09"))

        let book = try #require(try context.fetch(FetchDescriptor<Book>()).first)
        #expect(book.readings?.first?.startedAt == day("2026/10/03"))
    }
}
