//
//  AddQuotesSheet.swift
//  Amaris
//
//  Paste one or more quotes for a book. A blank line separates quotes.
//

import SwiftUI
import SwiftData

struct AddQuotesSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var books: [Book]

    @State private var selectedBook: Book?
    @State private var text = ""

    let initialBook: Book?

    /// Most relevant first: currently reading, then most recently finished.
    private var booksByRecency: [Book] {
        books.sorted { $0.recencyDate > $1.recencyDate }
    }

    private var parsedQuotes: [String] {
        QuoteExtractor.quotes(fromPastedText: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Quotes").font(.title2.bold())

            Picker("Book", selection: $selectedBook) {
                ForEach(booksByRecency) { book in
                    Text("\(book.displayTitle) — \(book.author)").tag(Optional(book))
                }
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Paste quotes here. Leave a blank line between quotes.")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 220)

            HStack {
                Text(parsedQuotes.count == 1 ? "1 quote" : "\(parsedQuotes.count) quotes")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedBook == nil || parsedQuotes.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            selectedBook = initialBook ?? booksByRecency.first
        }
    }

    private func save() {
        guard let book = selectedBook else { return }
        for text in parsedQuotes {
            context.insert(Quote(book: book, text: text, source: .manual))
        }
        try? context.save()
        dismiss()
    }
}
