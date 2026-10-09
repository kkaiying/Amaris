//
//  AmarisTheme.swift
//  Amaris
//
//  The two looks a widget can wear: Once Upon a Broken Heart (pink, whimsical)
//  and Alchemy (dark, gold, Alchemised). Chosen per widget.
//

import AppIntents
import CoreText
import SwiftUI

nonisolated enum AmarisTheme: String, CaseIterable, Codable, Sendable {
    case ouabh
    case alchemy
}

nonisolated extension AmarisTheme: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Theme"
    static let caseDisplayRepresentations: [AmarisTheme: DisplayRepresentation] = [
        .ouabh: "Once Upon a Broken Heart",
        .alchemy: "Alchemy",
    ]

    var displayName: String {
        switch self {
        case .ouabh: "Once Upon a Broken Heart"
        case .alchemy: "Alchemy"
        }
    }
}

nonisolated struct ThemePalette {
    var paper: Color          // widget background
    var paperDeep: Color      // secondary card background
    var ink: Color            // main text
    var muted: Color          // secondary text
    var accent: Color         // hearts, rings, highlights
    var accentText: Color     // accent-coloured text with good contrast
    var soft: Color           // light decorative tint
    var emptyDay: Color       // calendar day with no reading
    var emptyDayStroke: Color
    var line: Color           // hairlines and dividers
}

nonisolated extension AmarisTheme {
    var palette: ThemePalette {
        switch self {
        case .ouabh:
            ThemePalette(
                paper: Color(hex: 0xFBEDF0), paperDeep: Color(hex: 0xF9DDE5),
                ink: Color(hex: 0x4A2B35), muted: Color(hex: 0x82606C),
                accent: Color(hex: 0xE46F95), accentText: Color(hex: 0xB4466C),
                soft: Color(hex: 0xF2B7C9),
                emptyDay: Color(hex: 0xFFF7F9), emptyDayStroke: Color(hex: 0xEDBFCD),
                line: Color(hex: 0xF2B7C9)
            )
        case .alchemy:
            ThemePalette(
                paper: Color(hex: 0x1A1416), paperDeep: Color(hex: 0x2A1418),
                ink: Color(hex: 0xEFE4D2), muted: Color(hex: 0xA8998A),
                accent: Color(hex: 0xC9A55A), accentText: Color(hex: 0xC9A55A),
                soft: Color(hex: 0x6B1E2A),
                emptyDay: Color(hex: 0x211A1C), emptyDayStroke: Color(hex: 0x2E2427),
                line: Color(hex: 0xC9A55A).opacity(0.35)
            )
        }
    }

    /// Display headings: "October", "OCTOBER".
    func titleFont(_ size: CGFloat) -> Font {
        switch self {
        case .ouabh: .custom("Fraunces-SemiBoldItalic", fixedSize: size)
        case .alchemy: .custom("CinzelRoman-Bold", fixedSize: size)
        }
    }

    /// Small labels: handwritten for OUABH, engraved capitals for Alchemy.
    func labelFont(_ size: CGFloat) -> Font {
        switch self {
        case .ouabh: .custom("Caveat-Regular", fixedSize: size)
        case .alchemy: .custom("Cinzel-Regular", fixedSize: size)
        }
    }

    /// Quote text.
    func quoteFont(_ size: CGFloat) -> Font {
        switch self {
        case .ouabh: .custom("Fraunces-Italic", fixedSize: size)
        case .alchemy: .custom("CormorantGaramond-MediumItalic", fixedSize: size)
        }
    }

    /// Big numbers: "day 5", "V", "30", "XXX".
    func numberFont(_ size: CGFloat) -> Font {
        switch self {
        case .ouabh: .custom("CaveatRoman-Bold", fixedSize: size)
        case .alchemy: .custom("CinzelRoman-Bold", fixedSize: size)
        }
    }

    /// Plain small body text.
    func bodyFont(_ size: CGFloat) -> Font {
        switch self {
        case .ouabh: .custom("Fraunces-Regular", fixedSize: size)
        case .alchemy: .custom("CormorantGaramond-Italic", fixedSize: size)
        }
    }

    /// Labels are written in capitals for Alchemy.
    func label(_ text: String) -> String {
        self == .alchemy ? text.uppercased() : text
    }

    /// Alchemy counts in Roman numerals.
    func number(_ value: Int) -> String {
        self == .alchemy ? RomanNumeral.string(value) : String(value)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

nonisolated enum RomanNumeral {
    static func string(_ value: Int) -> String {
        guard value > 0 else { return "N" }   // nulla
        let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                      (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remaining = value
        var result = ""
        for (amount, numeral) in table {
            while remaining >= amount {
                result += numeral
                remaining -= amount
            }
        }
        return result
    }
}

/// Registers the bundled fonts (Shared/Fonts) once per process, for the app
/// and the widget extension alike.
nonisolated enum AmarisFonts {
    private static let registered: Void = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }()

    static func register() { _ = registered }
}
