//
//  CSVParser.swift
//  Amaris
//
//  Minimal RFC 4180 CSV parser. Goodreads exports quote fields that contain
//  commas, double quotes ("") and line breaks, so splitting on commas is not
//  enough.
//

import Foundation

nonisolated enum CSVParser {
    /// Parses CSV text into rows of fields.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var chars = text.makeIterator()
        var pending = chars.next()

        while let char = pending {
            pending = chars.next()

            if inQuotes {
                if char == "\"" {
                    if pending == "\"" {
                        field.append("\"")      // escaped quote ("")
                        pending = chars.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
                continue
            }

            switch char {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\n", "\r\n", "\r":            // Swift treats \r\n as one Character
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(char)
            }
        }

        // Last row when the file doesn't end with a newline.
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// Parses CSV text with a header row into dictionaries keyed by column name.
    static func parseWithHeader(_ text: String) -> [[String: String]] {
        var rows = parse(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        guard !rows.isEmpty else { return [] }
        let header = rows.removeFirst()
        return rows.map { fields in
            var dict: [String: String] = [:]
            for (index, name) in header.enumerated() where index < fields.count {
                dict[name] = fields[index]
            }
            return dict
        }
    }
}
