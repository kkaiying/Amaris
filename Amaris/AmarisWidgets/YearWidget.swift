//
//  YearWidget.swift
//  AmarisWidgets
//
//  Books finished so far this year.
//

import SwiftUI
import WidgetKit

struct YearEntry: TimelineEntry {
    var date: Date
    var theme: AmarisTheme
    var finished: [BookSnapshot]
}

struct YearProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> YearEntry {
        YearEntry(date: .now, theme: .ouabh, finished: [])
    }

    func snapshot(for configuration: ThemeIntent, in context: Context) async -> YearEntry {
        entry(for: configuration, at: .now)
    }

    func timeline(for configuration: ThemeIntent, in context: Context) async -> Timeline<YearEntry> {
        let now = Date.now
        return Timeline(entries: [entry(for: configuration, at: now)],
                        policy: .after(WidgetSchedule.nextMidnight(after: now)))
    }

    private func entry(for configuration: ThemeIntent, at date: Date) -> YearEntry {
        YearEntry(date: date, theme: configuration.theme,
                  finished: WidgetData.finishedThisYear(containing: date, in: WidgetData.context()))
    }
}

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AmarisYear", intent: ThemeIntent.self, provider: YearProvider()) { entry in
            YearWidgetView(entry: entry)
                .containerBackground(for: .widget) { ThemeBackground(theme: entry.theme, deep: true) }
        }
        .configurationDisplayName("Year So Far")
        .description("How many books you've finished this year.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct YearWidgetView: View {
    let entry: YearEntry
    private var theme: AmarisTheme { entry.theme }
    private var palette: ThemePalette { theme.palette }
    private var year: Int { Calendar.current.component(.year, from: entry.date) }

    var body: some View {
        switch theme {
        case .ouabh: ouabh
        case .alchemy: alchemy
        }
    }

    private var ouabh: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(String(year)), so far").font(theme.labelFont(15)).foregroundStyle(palette.accentText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.finished.count)")
                    .font(.custom("Fraunces-SemiBoldItalic", fixedSize: 46))
                    .foregroundStyle(palette.ink)
                ZStack {
                    Heart().fill(.white).frame(width: 18, height: 16)
                    Heart().fill(palette.accent).frame(width: 15, height: 13)
                }
            }
            Text(entry.finished.count == 1 ? "book read" : "books read")
                .font(theme.labelFont(16))
                .foregroundStyle(Color(hex: 0x7D5864))
            Spacer(minLength: 4)
            HStack(alignment: .bottom, spacing: 2.5) {
                // The latest finished books as little spines.
                ForEach(Array(entry.finished.prefix(7).enumerated()), id: \.offset) { index, book in
                    CoverArt(fileName: book.coverFileName, title: "", maxPixelSize: 120)
                        .frame(width: [11, 9, 12, 10, 12, 9, 11][index], height: [34, 38, 31, 36, 35, 32, 37][index])
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                }
                Sparkle().fill(.white).frame(width: 13, height: 13).padding(.leading, 4).padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(15)
    }

    private var alchemy: some View {
        ZStack {
            TransmutationCircle(variant: .year)
                .stroke(palette.accent, lineWidth: 1)
                .padding(10)
                .opacity(0.22)
            Circle()
                .stroke(palette.accent, style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                .padding(19)
                .opacity(0.22)
            GoldInnerBorder()
            VStack(spacing: 2) {
                Text(theme.number(year)).font(theme.labelFont(8.5)).tracking(2.5).foregroundStyle(palette.muted)
                Text(theme.number(entry.finished.count))
                    .font(theme.numberFont(entry.finished.count > 38 ? 24 : 34))
                    .foregroundStyle(palette.accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                Text(entry.finished.count == 1 ? "tome finished" : "tomes finished")
                    .font(theme.quoteFont(14))
                    .foregroundStyle(palette.ink)
            }
        }
    }
}
