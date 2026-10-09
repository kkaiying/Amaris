//
//  CalendarWidget.swift
//  AmarisWidgets
//
//  This month, with a book cover on every day I was reading.
//

import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    var date: Date
    var theme: AmarisTheme
    var days: [Date: [BookSnapshot]]

    /// Distinct books read this month so far.
    var bookCount: Int { Set(days.values.flatMap { $0 }).count }
}

struct CalendarProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        CalendarEntry(date: .now, theme: .ouabh, days: [:])
    }

    func snapshot(for configuration: ThemeIntent, in context: Context) async -> CalendarEntry {
        entry(for: configuration, at: .now)
    }

    func timeline(for configuration: ThemeIntent, in context: Context) async -> Timeline<CalendarEntry> {
        let now = Date.now
        return Timeline(entries: [entry(for: configuration, at: now)],
                        policy: .after(WidgetSchedule.nextMidnight(after: now)))
    }

    private func entry(for configuration: ThemeIntent, at date: Date) -> CalendarEntry {
        CalendarEntry(date: date, theme: configuration.theme,
                      days: WidgetData.monthDays(containing: date, in: WidgetData.context()))
    }
}

struct CalendarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AmarisCalendar", intent: ThemeIntent.self, provider: CalendarProvider()) { entry in
            CalendarWidgetView(entry: entry)
                .containerBackground(for: .widget) { ThemeBackground(theme: entry.theme) }
        }
        .configurationDisplayName("Reading Calendar")
        .description("This month, with a cover on every day you were reading.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct CalendarWidgetView: View {
    let entry: CalendarEntry
    private var theme: AmarisTheme { entry.theme }
    private var palette: ThemePalette { theme.palette }
    private var calendar: Calendar { .current }

    private var month: DateInterval { ReadingCalendar.month(containing: entry.date) }

    private var cells: [Date?] {
        let first = month.start
        let blanks = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let days = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: blanks) + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        ZStack(alignment: .top) {
            if theme == .alchemy {
                TransmutationCircle(variant: .calendar)
                    .stroke(palette.accent, lineWidth: 0.8)
                    .frame(width: 240, height: 240)
                    .opacity(0.18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 80, y: -80)
                GoldInnerBorder()
            }

            VStack(spacing: 0) {
                header
                VStack(spacing: 6) {
                    weekdays
                    grid
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, theme == .ouabh ? 2 : 4)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        let monthName = entry.date.formatted(.dateTime.month(.wide))
        let year = calendar.component(.year, from: entry.date)
        switch theme {
        case .ouabh:
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(monthName).font(theme.titleFont(24)).foregroundStyle(palette.ink)
                    Text(String(year)).font(theme.labelFont(17)).foregroundStyle(palette.accentText)
                    Spacer()
                    Sparkle().fill(palette.accent).frame(width: 15, height: 15)
                        .overlay(alignment: .bottomLeading) {
                            Sparkle().fill(palette.soft).frame(width: 8, height: 8).offset(x: -12, y: 8)
                        }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .background(Gingham())
                ScallopEdge(scallopWidth: 14)
                    .fill(Color(hex: 0xFDE9EF))
                    .frame(height: 7)
            }
        case .alchemy:
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(monthName.uppercased()).font(theme.titleFont(19)).tracking(3.5).foregroundStyle(palette.accent)
                Text(theme.number(year)).font(theme.labelFont(10)).tracking(2).foregroundStyle(palette.muted)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 4)
        }
    }

    private var weekdays: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(theme == .ouabh ? theme.labelFont(14) : theme.labelFont(9))
                    .foregroundStyle(theme == .ouabh ? palette.accentText : palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        let rows = Int(ceil(Double(cells.count) / 7))
        let gap: CGFloat = 5
        return GeometryReader { geometry in
            let cellWidth = (geometry.size.width - gap * 6) / 7
            let cellHeight = min(cellWidth * 1.4, (geometry.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows))
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { column in
                            let index = row * 7 + column
                            Group {
                                if index < cells.count, let day = cells[index] {
                                    DayTile(day: day, books: entry.days[day] ?? [], theme: theme,
                                            isToday: calendar.isDate(day, inSameDayAs: entry.date))
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(width: cellWidth, height: cellHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        let count = entry.bookCount
        switch theme {
        case .ouabh:
            HStack(spacing: 6) {
                AppleDoodle().frame(width: 14, height: 16)
                Text(count == 1 ? "1 book this month" : "\(count) books this month")
                    .font(theme.labelFont(17))
                    .foregroundStyle(palette.accentText)
                    .overlay(alignment: .bottom) {
                        Squiggle().stroke(palette.soft, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                            .frame(height: 4).offset(y: 3)
                    }
                Spacer()
            }
        case .alchemy:
            HStack(spacing: 7) {
                SunGlyph(color: palette.accent).frame(width: 11, height: 11)
                Text("\(theme.number(count)) \(count == 1 ? "VOLUME" : "VOLUMES") THIS MONTH")
                    .font(theme.labelFont(9.5))
                    .tracking(1.8)
                    .foregroundStyle(palette.muted)
                Spacer()
            }
        }
    }
}

private struct DayTile: View {
    let day: Date
    let books: [BookSnapshot]
    let theme: AmarisTheme
    let isToday: Bool

    private var palette: ThemePalette { theme.palette }
    private var radius: CGFloat { theme == .ouabh ? 6 : 2.5 }
    private var dayNumber: String { String(Calendar.current.component(.day, from: day)) }

    var body: some View {
        ZStack {
            if books.isEmpty {
                empty
            } else {
                covers
            }
        }
        .overlay { todayMark }
    }

    @ViewBuilder
    private var empty: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        ZStack {
            shape.fill(palette.emptyDay)
            if theme == .ouabh {
                shape.strokeBorder(palette.emptyDayStroke, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
            } else {
                shape.strokeBorder(palette.emptyDayStroke, lineWidth: 1)
            }
            Text(dayNumber)
                .font(theme == .ouabh ? .custom("Fraunces-Regular", fixedSize: 10) : .custom("CormorantGaramond-Medium", fixedSize: 11))
                .foregroundStyle(theme == .ouabh ? Color(hex: 0xC09AA6) : Color(hex: 0x6F6259))
        }
    }

    private var covers: some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        return HStack(spacing: theme == .ouabh ? 1.5 : 1) {
            ForEach(Array(books.prefix(2).enumerated()), id: \.offset) { _, book in
                CoverArt(fileName: book.coverFileName, title: "", maxPixelSize: 120)
            }
        }
        .background(theme == .ouabh ? palette.paper : palette.accent)
        .clipShape(shape)
        .overlay {
            if theme == .alchemy { shape.strokeBorder(palette.accent.opacity(0.55), lineWidth: 0.8) }
        }
        .shadow(color: theme == .ouabh ? Color(hex: 0x3C1423).opacity(0.22) : .clear, radius: 1.5, y: 1)
        .overlay(alignment: .bottomTrailing) {
            if books.count > 2 { moreBadge(books.count - 2) }
        }
    }

    @ViewBuilder
    private func moreBadge(_ extra: Int) -> some View {
        switch theme {
        case .ouabh:
            ZStack {
                Heart().fill(.white).frame(width: 17, height: 15)
                Heart().fill(palette.accent).frame(width: 14, height: 12)
                Text("+\(extra)").font(.system(size: 6.5, weight: .bold)).foregroundStyle(.white).offset(y: -0.5)
            }
            .offset(x: 4, y: 4)
        case .alchemy:
            Text("+\(extra)")
                .font(.custom("Cinzel-Regular", fixedSize: 7))
                .foregroundStyle(palette.paper)
                .padding(.horizontal, 2.5)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 1.5))
                .padding(2)
        }
    }

    @ViewBuilder
    private var todayMark: some View {
        if isToday {
            switch theme {
            case .ouabh:
                InkCircle()
                    .stroke(palette.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .padding(-6)
            case .alchemy:
                RoundedRectangle(cornerRadius: radius + 1.5)
                    .stroke(palette.accent, lineWidth: 1.4)
                    .padding(-2.5)
                    .shadow(color: palette.accent.opacity(0.6), radius: 4)
            }
        }
    }
}
