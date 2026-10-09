//
//  QuoteExtractor.swift
//  Amaris
//
//  Pulls favourite quotes out of a Goodreads review.
//
//  Review format: quotes come first, wrapped in <i>…</i> or <i><b>…</b></i>
//  (closing-tag order varies). Goodreads stores line breaks as <br/>, so
//  multiple quotes in one block are separated by <br/><br/>. A review can
//  also contain several separate <i> blocks.
//

import Foundation

nonisolated enum QuoteExtractor {
    static func quotes(fromReview review: String) -> [String] {
        let italicBlock = /(?s)<i>(.*?)<\/i>/
        let lineBreaks = /(?:<br\s*\/?>)+/

        var result: [String] = []
        for match in review.matches(of: italicBlock) {
            let block = String(match.1)
                .replacing(/<\/?b>/, with: "")
            for piece in block.split(separator: lineBreaks) {
                let quote = decodeEntities(String(piece))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !quote.isEmpty {
                    result.append(quote)
                }
            }
        }
        return result
    }

    /// Splits pasted text into quotes: a blank line separates one quote from the next.
    static func quotes(fromPastedText text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: /\n[ \t]*\n\s*/)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Decodes the HTML entities Goodreads uses in review text.
    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var output = text
        let named = ["&quot;": "\"", "&apos;": "'", "&#39;": "'",
                     "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, char) in named {
            output = output.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities like &#8220; or &#x201C;
        output = output.replacing(/&#(x?)([0-9a-fA-F]+);/) { match in
            let radix = match.1.isEmpty ? 10 : 16
            guard let code = UInt32(match.2, radix: radix),
                  let scalar = Unicode.Scalar(code) else { return String(match.0) }
            return String(Character(scalar))
        }
        // &amp; last, so "&amp;quot;" becomes "&quot;" rather than "\"".
        return output.replacingOccurrences(of: "&amp;", with: "&")
    }
}
