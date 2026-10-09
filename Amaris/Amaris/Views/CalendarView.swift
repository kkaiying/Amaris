//
//  CalendarView.swift
//  Amaris
//
//  A whole year at a glance: every day I was reading shows that book's cover.
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query private var readings: [Reading]

    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var openBook: Book?

    private var calendar: Calendar { .current }

    private var yearInterval: DateInterval {
        calendar.dateInterval(of: .year, for: calendar.date(from: DateComponents(year: year))!)!
    }

    private var booksByDay: [Date: [Book]] {
        ReadingCalendar.booksByDay(readings, in: yearInterval)
    }

    private var months: [Date] {
        (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: yearInterval.start) }
    }

    /// Years from the first dated reading up to now.
    private var yearRange: ClosedRange<Int> {
        let current = calendar.component(.year, from: .now)
        let first = readings.compactMap(\.startedAt).min().map { calendar.component(.year, from: $0) } ?? current
        return min(first, current)...current
    }

    private var finishedThisYear: [Reading] {
        readings.filter { reading in
            guard let finished = reading.finishedAt, reading.outcome != .dnf else { return false }
            return yearInterval.contains(finished)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summary
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 28, alignment: .top)],
                          spacing: 28) {
                    ForEach(months, id: \.self) { month in
                        MonthGrid(month: month, booksByDay: booksByDay, openBook: $openBook)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Calendar")
        .navigationSubtitle(String(year))
        .toolbar {
            ToolbarItemGroup {
                Button { year -= 1 } label: { Label("Previous Year", systemImage: "chevron.left") }
                    .disabled(year <= yearRange.lowerBound)
                Button("Today") { year = calendar.component(.year, from: .now) }
                    .disabled(year == calendar.component(.year, from: .now))
                Button { year += 1 } label: { Label("Next Year", systemImage: "chevron.right") }
                    .disabled(year >= yearRange.upperBound)
            }
        }
        .navigationDestination(item: $openBook) { BookDetailView(book: $0) }
    }

    private var summary: some View {
        let finished = finishedThisYear
        let pages = finished.compactMap { $0.book?.pageCount }.reduce(0, +)
        let daysReading = booksByDay.count
        return HStack(spacing: 28) {
            Stat(value: "\(finished.count)", label: finished.count == 1 ? "book finished" : "books finished")
            if pages > 0 {
                Stat(value: pages.formatted(), label: "pages")
            }
            Stat(value: "\(daysReading)", label: daysReading == 1 ? "day reading" : "days reading")
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct MonthGrid: View {
    let month: Date
    let booksByDay: [Date: [Book]]
    @Binding var openBook: Book?

    private var calendar: Calendar { .current }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    private var days: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    /// Empty cells before the 1st, so days line up under the right weekday.
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.aspectRatio(2 / 3, contentMode: .fit)
                }
                ForEach(days, id: \.self) { day in
                    DayCell(day: day, books: booksByDay[day] ?? [], openBook: $openBook)
                }
            }
        }
    }
}

private struct DayCell: View {
    let day: Date
    let books: [Book]
    @Binding var openBook: Book?

    @State private var isShowingBooks = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var dayNumber: String { String(Calendar.current.component(.day, from: day)) }

    var body: some View {
        ZStack {
            if books.isEmpty {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary.opacity(0.5))
                Text(dayNumber)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                // Two books on one day split the cell side by side.
                HStack(spacing: 1) {
                    ForEach(books.prefix(2)) { book in
                        CoverArt(book: book, maxPixelSize: 160)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .bottomTrailing) {
                    if books.count > 2 {
                        Text("+\(books.count - 2)")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 3)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(2)
                    }
                }
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 3).strokeBorder(.tint, lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if books.count == 1 { openBook = books[0] }
            else if books.count > 1 { isShowingBooks = true }
        }
        .popover(isPresented: $isShowingBooks) {
            VStack(alignment: .leading, spacing: 8) {
                Text(day.formatted(date: .complete, time: .omitted))
                    .font(.headline)
                ForEach(books) { book in
                    Button {
                        isShowingBooks = false
                        openBook = book
                    } label: {
                        HStack(spacing: 10) {
                            CoverImage(book: book, maxPixelSize: 160).frame(width: 28)
                            Text(book.displayTitle)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(width: 280)
        }
        .help(books.isEmpty ? day.formatted(date: .abbreviated, time: .omitted)
              : "\(day.formatted(date: .abbreviated, time: .omitted)): \(books.map(\.displayTitle).joined(separator: ", "))")
    }
}
