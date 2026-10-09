//
//  QuoteWidget.swift
//  AmarisWidgets
//
//  A saved quote, changing every hour, with a button for the next one.
//  Fan art chosen in the app's Settings sits faintly behind it.
//

import AppIntents
import SwiftUI
import WidgetKit

struct QuoteEntry: TimelineEntry {
    var date: Date
    var theme: AmarisTheme
    var quote: QuoteSnapshot?
    var favouritesOnly: Bool
}

struct QuoteProvider: AppIntentTimelineProvider {
    /// How many hours of quotes to schedule ahead.
    private let hoursAhead = 12

    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, theme: .ouabh, quote: Self.sample, favouritesOnly: false)
    }

    func snapshot(for configuration: QuoteIntent, in context: Context) async -> QuoteEntry {
        let quotes = WidgetData.quotes(favouritesOnly: configuration.favouritesOnly, in: WidgetData.context())
        return QuoteEntry(date: .now, theme: configuration.theme,
                          quote: QuoteRotation.quote(at: .now, from: quotes) ?? Self.sample,
                          favouritesOnly: configuration.favouritesOnly)
    }

    func timeline(for configuration: QuoteIntent, in context: Context) async -> Timeline<QuoteEntry> {
        let quotes = WidgetData.quotes(favouritesOnly: configuration.favouritesOnly, in: WidgetData.context())
        var entries = [QuoteEntry(date: .now, theme: configuration.theme,
                                  quote: QuoteRotation.quote(at: .now, from: quotes),
                                  favouritesOnly: configuration.favouritesOnly)]
        var next = QuoteRotation.nextChange(after: .now)
        for _ in 0..<hoursAhead {
            entries.append(QuoteEntry(date: next, theme: configuration.theme,
                                      quote: QuoteRotation.quote(at: next, from: quotes),
                                      favouritesOnly: configuration.favouritesOnly))
            next = QuoteRotation.nextChange(after: next)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    static let sample = QuoteSnapshot(
        text: "Some loves come fast, some loves come slow.",
        book: BookSnapshot(title: "The Mirror of Infinite Endings", author: "Stephanie Garber", coverFileName: nil),
        isFavourite: true
    )
}

struct QuoteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AmarisQuote", intent: QuoteIntent.self, provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        ThemeBackground(theme: entry.theme)
                        FanArtLayer(theme: entry.theme)
                    }
                }
        }
        .configurationDisplayName("Quote")
        .description("One of your saved quotes, changing every hour.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

/// The chosen fan art, faded and fading out towards the quote.
private struct FanArtLayer: View {
    let theme: AmarisTheme

    var body: some View {
        if let image = FanArtStore.image(for: theme) {
            GeometryReader { geometry in
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width * 0.62, height: geometry.size.height)
                    .clipped()
                    .opacity(theme == .ouabh ? 0.22 : 0.2)
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

struct QuoteWidgetView: View {
    let entry: QuoteEntry
    private var theme: AmarisTheme { entry.theme }
    private var palette: ThemePalette { theme.palette }

    var body: some View {
        if let quote = entry.quote {
            switch theme {
            case .ouabh: ouabh(quote)
            case .alchemy: alchemy(quote)
            }
        } else {
            emptyState
        }
    }

    /// Smaller text for longer quotes, so they fit the widget.
    private func quoteSize(_ text: String, base: CGFloat) -> CGFloat {
        switch text.count {
        case ..<80: base
        case ..<140: base - 2.5
        case ..<220: base - 4.5
        default: base - 6
        }
    }

    // MARK: Once Upon a Broken Heart

    private func ouabh(_ quote: QuoteSnapshot) -> some View {
        HStack(alignment: .top, spacing: 16) {
            CoverTile(book: quote.book, cornerRadius: 4)
                .frame(width: 66)
                .shadow(color: Color(hex: 0x3C1423).opacity(0.3), radius: 4, y: 3)
                .overlay(alignment: .top) {
                    WashiTape().frame(width: 44, height: 14).rotationEffect(.degrees(6)).offset(y: -7)
                }
                .rotationEffect(.degrees(-4))
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 0) {
                Text("“\(quote.text)”")
                    .font(theme.quoteFont(quoteSize(quote.text, base: 15.5)))
                    .lineSpacing(2)
                    .foregroundStyle(palette.ink)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 6)
                HStack(spacing: 7) {
                    WaxSeal().frame(width: 22, height: 22)
                    Text(quote.book.author)
                        .font(theme.labelFont(16))
                        .foregroundStyle(palette.accentText)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    nextButton
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .overlay(alignment: .topTrailing) {
            Sparkle().fill(palette.soft).frame(width: 11, height: 11).padding(12)
        }
    }

    // MARK: Alchemy

    private func alchemy(_ quote: QuoteSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
                Text("“\(quote.text)”")
                    .font(theme.quoteFont(quoteSize(quote.text, base: 19)))
                    .lineSpacing(1)
                    .foregroundStyle(palette.ink)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.trailing, 30)
                Spacer(minLength: 6)
                HStack(spacing: 8) {
                    CoverTile(book: quote.book, cornerRadius: 1.5, maxPixelSize: 80)
                        .frame(width: 17)
                        .overlay(RoundedRectangle(cornerRadius: 1.5).stroke(palette.accent, lineWidth: 0.8))
                    // Title and author if they fit, otherwise just the title.
                    ViewThatFits(in: .horizontal) {
                        attribution("\(quote.book.displayTitle) · \(quote.book.author)")
                        attribution(quote.book.displayTitle)
                    }
                    Spacer(minLength: 4)
                    nextButton
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Decorations sit behind without affecting the layout.
            .background(alignment: .trailing) {
                TransmutationCircle(variant: .quote)
                    .stroke(palette.accent, lineWidth: 0.9)
                    .frame(width: 180, height: 180)
                    .opacity(0.16)
                    .offset(x: 30)
            }
            .overlay { GoldInnerBorder() }
            .clipped()
    }

    private func attribution(_ text: String) -> some View {
        Text(text.uppercased())
            .font(theme.labelFont(8.5))
            .tracking(1.6)
            .foregroundStyle(palette.accent)
            .lineLimit(1)
    }

    // MARK: Shared

    private var nextButton: some View {
        Button(intent: NextQuoteIntent()) {
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: theme == .ouabh ? .bold : .regular))
                .foregroundStyle(theme == .ouabh ? palette.accentText : palette.accent)
                .frame(width: 32, height: 32)
                .background {
                    if theme == .ouabh {
                        Circle().fill(Color(hex: 0xFFF7F9)).overlay(Circle().stroke(palette.soft, lineWidth: 1.3))
                    } else {
                        Circle().stroke(palette.accent, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next quote")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(theme.label(entry.favouritesOnly ? "No favourite quotes yet" : "No quotes yet"))
                .font(theme == .ouabh ? theme.labelFont(20) : theme.labelFont(11))
                .tracking(theme == .alchemy ? 2 : 0)
                .foregroundStyle(palette.accentText)
            Text("Add some in Amaris")
                .font(theme.bodyFont(12))
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { if theme == .alchemy { GoldInnerBorder() } }
    }
}
