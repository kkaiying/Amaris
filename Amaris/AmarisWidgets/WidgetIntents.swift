//
//  WidgetIntents.swift
//  AmarisWidgets
//
//  Widget options (right-click a widget → Edit Widget) and the quote widget's
//  "next" button.
//

import AppIntents
import WidgetKit

struct ThemeIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Theme"
    static let description = IntentDescription("Choose how the widget looks.")

    @Parameter(title: "Theme", default: .ouabh)
    var theme: AmarisTheme

    init() {}
    init(theme: AmarisTheme) { self.theme = theme }
}

struct QuoteIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quote"
    static let description = IntentDescription("Choose how the widget looks and which quotes it shows.")

    @Parameter(title: "Theme", default: .ouabh)
    var theme: AmarisTheme

    @Parameter(title: "Favourites only", default: false)
    var favouritesOnly: Bool

    init() {}
    init(theme: AmarisTheme) { self.theme = theme }
}

struct NextQuoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Quote"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        QuoteRotation.advance()
        return .result()
    }
}
