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
