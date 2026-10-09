//
//  WidgetChrome.swift
//  AmarisWidgets
//
//  Pieces shared by the widgets: backgrounds, cover tiles, midnight refresh.
//

import SwiftUI
import WidgetKit

/// The card behind every widget.
struct ThemeBackground: View {
    let theme: AmarisTheme
    var deep = false

    var body: some View {
        switch theme {
        case .ouabh:
            if deep {
                PolkaDots(base: theme.palette.paperDeep)
            } else {
                theme.palette.paper
            }
        case .alchemy:
            ZStack {
                if deep {
                    theme.palette.paperDeep
                } else {
                    LinearGradient(colors: [Color(hex: 0x241417), theme.palette.paper],
                                   startPoint: .topLeading, endPoint: .center)
                }
            }
        }
    }
}

/// Alchemy's fine gold border, inset from the widget's rounded edge.
struct GoldInnerBorder: View {
    var body: some View {
        ContainerRelativeShape()
            .inset(by: 8)
            .stroke(AmarisTheme.alchemy.palette.line, lineWidth: 1)
    }
}

/// A book cover at 2:3, cropped to fill, with a placeholder when missing.
struct CoverTile: View {
    let book: BookSnapshot
    var cornerRadius: CGFloat = 5
    var maxPixelSize = 300

    var body: some View {
        CoverArt(fileName: book.coverFileName, title: book.displayTitle, maxPixelSize: maxPixelSize)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

enum WidgetSchedule {
    /// Refresh just after midnight so "today" moves on.
    static func nextMidnight(after date: Date) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return tomorrow.addingTimeInterval(60)
    }

    /// Calendar days since `start`, counting the start day as day 1.
    static func dayNumber(since start: Date, today: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: today)).day ?? 0
        return max(days + 1, 1)
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
