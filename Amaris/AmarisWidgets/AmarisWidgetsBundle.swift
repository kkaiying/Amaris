//
//  AmarisWidgetsBundle.swift
//  AmarisWidgets
//
//  Created by Tey Kai Ying on 09/10/2026.
//

import WidgetKit
import SwiftUI

@main
struct AmarisWidgetsBundle: WidgetBundle {
    init() {
        AmarisFonts.register()
    }

    var body: some Widget {
        CalendarWidget()
        QuoteWidget()
        ReadingNowWidget()
        YearWidget()
    }
}
