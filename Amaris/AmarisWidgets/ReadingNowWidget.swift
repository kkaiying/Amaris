//
//  ReadingNowWidget.swift
//  AmarisWidgets
//
//  The book I'm reading right now, and how many days I've been at it.
//

import SwiftUI
import WidgetKit

struct ReadingNowEntry: TimelineEntry {
    var date: Date
    var theme: AmarisTheme
    var book: BookSnapshot?
    var startedAt: Date?
    /// Days actually read (on-hold days don't count); defaults to every day since the start.
    var daysRead: Int?

    var dayNumber: Int? {
        daysRead ?? startedAt.map { WidgetSchedule.dayNumber(since: $0, today: date) }
    }
}

struct ReadingNowProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ReadingNowEntry {
        ReadingNowEntry(date: .now, theme: .ouabh,
                        book: BookSnapshot(title: "Your current read", author: "", coverFileName: nil),
                        startedAt: .now)
    }

    func snapshot(for configuration: ThemeIntent, in context: Context) async -> ReadingNowEntry {
        entry(for: configuration, at: .now)
    }

    func timeline(for configuration: ThemeIntent, in context: Context) async -> Timeline<ReadingNowEntry> {
        let now = Date.now
        return Timeline(entries: [entry(for: configuration, at: now)],
                        policy: .after(WidgetSchedule.nextMidnight(after: now)))
    }

    private func entry(for configuration: ThemeIntent, at date: Date) -> ReadingNowEntry {
        let current = WidgetData.currentBook(in: WidgetData.context(), today: date)
        return ReadingNowEntry(date: date, theme: configuration.theme, book: current?.book,
                               startedAt: current?.startedAt, daysRead: current?.daysRead)
    }
}

struct ReadingNowWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AmarisReadingNow", intent: ThemeIntent.self, provider: ReadingNowProvider()) { entry in
            ReadingNowView(entry: entry)
                .containerBackground(for: .widget) { ThemeBackground(theme: entry.theme, deep: true) }
        }
        .configurationDisplayName("Currently Reading")
        .description("The book you're reading and how long you've been at it.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct ReadingNowView: View {
    let entry: ReadingNowEntry
    private var theme: AmarisTheme { entry.theme }
    private var palette: ThemePalette { theme.palette }

    var body: some View {
        Group {
            if let book = entry.book, let day = entry.dayNumber, let start = entry.startedAt {
                switch theme {
                case .ouabh: ouabh(book, day: day, start: start)
                case .alchemy: alchemy(book, day: day, start: start)
                }
            } else {
                Text(theme.label("Nothing on the go"))
                    .font(theme == .ouabh ? theme.labelFont(19) : theme.labelFont(10))
                    .tracking(theme == .alchemy ? 2 : 0)
                    .foregroundStyle(palette.accentText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .overlay { if theme == .alchemy { GoldInnerBorder() } }
    }

    private func ouabh(_ book: BookSnapshot, day: Int, start: Date) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PostageStamp { CoverTile(book: book, cornerRadius: 0, maxPixelSize: 240) }
                .frame(width: 62)
                .overlay(alignment: .bottomLeading) {
                    Postmark(color: palette.accentText.opacity(0.5)).scaleEffect(0.75).offset(x: 18, y: 8)
                }
                .rotationEffect(.degrees(-3))
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("currently reading...")
                    .font(theme.labelFont(14))
                    .foregroundStyle(palette.accentText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Text("day \(day)")
                        .font(theme.numberFont(30))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Heart().fill(palette.accent).frame(width: 11, height: 10)
                }
                .fixedSize(horizontal: false, vertical: true)
                Text("since \(WidgetSchedule.shortDate(start))")
                    .font(theme.bodyFont(9.5))
                    .foregroundStyle(palette.muted)
            }
        }
        .padding(14)
    }

    private func alchemy(_ book: BookSnapshot, day: Int, start: Date) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ArchFrame(color: palette.accent) {
                CoverArt(fileName: book.coverFileName, title: book.displayTitle, maxPixelSize: 240)
                    .aspectRatio(2 / 3.2, contentMode: .fit)
            }
            .frame(width: 66)
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 0) {
                Text("READING").font(theme.labelFont(8.5)).tracking(1.8).foregroundStyle(palette.muted)
                Spacer(minLength: 0)
                Text(theme.number(day))
                    .font(theme.numberFont(day > 30 ? 20 : 28))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("\(day == 1 ? "day" : "days") since \(WidgetSchedule.shortDate(start))")
                    .font(theme.bodyFont(12))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                AirGlyph().stroke(palette.accent, lineWidth: 1.1).frame(width: 13, height: 12).padding(.top, 8)
            }
        }
        .padding(16)
    }
}
