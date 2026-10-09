//
//  QuotesView.swift
//  Amaris
//
//  All quotes, grouped by book. Favourite, edit, merge, delete.
//

import SwiftUI
import SwiftData

struct QuotesView: View {
    @Environment(AppModel.self) private var model
    @Query private var quotes: [Quote]

    @State private var favouritesOnly = false
    @State private var search = ""

    private var groups: [(book: Book, quotes: [Quote])] {
        let matching = quotes.filter { quote in
            guard quote.book != nil else { return false }
            if favouritesOnly && !quote.isFavourite { return false }
            return search.isEmpty
                || quote.text.localizedCaseInsensitiveContains(search)
                || (quote.book?.title.localizedCaseInsensitiveContains(search) ?? false)
        }
        let byBook = Dictionary(grouping: matching) { $0.book!.persistentModelID }
        return byBook.values
            .map { quotes in (quotes[0].book!, quotes.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.book.recencyDate > $1.book.recencyDate }
    }

    var body: some View {
        Group {
            if quotes.isEmpty {
                ContentUnavailableView {
                    Label("No quotes yet", systemImage: "quote.opening")
                } actions: {
                    Button("Add Quotes…") { model.startAddingQuotes() }
                }
            } else if groups.isEmpty {
                ContentUnavailableView(favouritesOnly && search.isEmpty ? "No favourites yet" : "No matching quotes",
                                       systemImage: favouritesOnly ? "heart" : "magnifyingglass")
            } else {
                list
            }
        }
        .navigationTitle("Quotes")
        .navigationSubtitle("\(quotes.count) quotes · \(quotes.filter(\.isFavourite).count) favourites")
        .searchable(text: $search, prompt: "Quote or book")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $favouritesOnly) {
                    Label("Favourites Only", systemImage: favouritesOnly ? "heart.fill" : "heart")
                }
                .help("Show favourites only")
            }
            ToolbarItem {
                Button { model.startAddingQuotes() } label: {
                    Label("Add Quotes", systemImage: "plus")
                }
                .help("Add quotes (⌘N)")
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(groups, id: \.book.persistentModelID) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        BookHeader(book: group.book)
                        ForEach(Array(group.quotes.enumerated()), id: \.element.persistentModelID) { index, quote in
                            QuoteCard(quote: quote,
                                      next: index + 1 < group.quotes.count ? group.quotes[index + 1] : nil)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct BookHeader: View {
    @Environment(AppModel.self) private var model
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(book: book).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.displayTitle).font(.headline)
                Text(book.author).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button { model.startAddingQuotes(for: book) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add quotes from this book")
        }
    }
}

private struct QuoteCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var quote: Quote
    /// The following quote from the same book, for "Merge with Next".
    let next: Quote?

    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(quote.text)
                .font(.system(.body, design: .serif))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                Button {
                    quote.isFavourite.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: quote.isFavourite ? "heart.fill" : "heart")
                        .foregroundStyle(quote.isFavourite ? Color.pink : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(quote.isFavourite ? "Remove from favourites" : "Add to favourites")

                Menu {
                    Button("Edit…") { isEditing = true }
                    Button("Merge with Next Quote", action: mergeWithNext)
                        .disabled(next == nil)
                    Divider()
                    Button("Delete…", role: .destructive) { isConfirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .sheet(isPresented: $isEditing) { EditQuoteSheet(quote: quote) }
        .confirmationDialog("Delete this quote?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                context.delete(quote)
                try? context.save()
            }
        }
    }

    /// Joins a quote that the Goodreads import split across two paragraphs.
    private func mergeWithNext() {
        guard let next else { return }
        quote.text += "\n\n" + next.text
        quote.isFavourite = quote.isFavourite || next.isFavourite
        context.delete(next)
        try? context.save()
    }
}

private struct EditQuoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var quote: Quote
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Quote").font(.title2.bold())
            TextEditor(text: $text)
                .font(.system(.body, design: .serif))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                .frame(minHeight: 180)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    quote.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? context.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { text = quote.text }
    }
}
