//
//  LibraryView.swift
//  Amaris
//
//  Grid of book covers, grouped by year read, with search, filter and sort.
//

import SwiftUI
import SwiftData

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all = "All", reading = "Reading", read = "Read", dnf = "DNF"
    var id: Self { self }

    func includes(_ book: Book) -> Bool {
        switch self {
        case .all: true
        case .reading: book.status == .reading
        case .read: book.status == .read
        case .dnf: book.status == .dnf
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent = "Recently Read", title = "Title", author = "Author", rating = "Rating"
    var id: Self { self }
}

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Query private var books: [Book]

    @State private var filter: LibraryFilter = .all
    @State private var sort: LibrarySort = .recent
    @State private var search = ""

    private var shownBooks: [Book] {
        let matching = books.filter { book in
            filter.includes(book) && (search.isEmpty
                || book.title.localizedCaseInsensitiveContains(search)
                || book.author.localizedCaseInsensitiveContains(search))
        }
        switch sort {
        case .recent: return matching.sorted { $0.recencyDate > $1.recencyDate }
        case .title: return matching.sorted { $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending }
        case .author: return matching.sorted { ($0.author, $0.title) < ($1.author, $1.title) }
        case .rating: return matching.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }
    }

    /// Sections for "Recently Read": reading now, then each year, then DNF.
    private var sections: [(title: String, books: [Book])] {
        guard sort == .recent else { return [("", shownBooks)] }
        var groups: [String: [Book]] = [:]
        var order: [String] = []
        for book in shownBooks {
            let key: String
            switch book.status {
            case .reading: key = "Currently Reading"
            case .dnf: key = "Did Not Finish"
            case .read:
                key = book.latestReading?.finishedAt.map { String(Calendar.current.component(.year, from: $0)) } ?? "Read"
            }
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(book)
        }
        // Keep DNF at the end regardless of dates.
        let dnf = "Did Not Finish"
        order = order.filter { $0 != dnf } + (groups[dnf] == nil ? [] : [dnf])
        return order.map { ($0, groups[$0]!) }
    }

    var body: some View {
        Group {
            if books.isEmpty {
                ContentUnavailableView {
                    Label("No books yet", systemImage: "books.vertical")
                } description: {
                    Text("Import your Goodreads library export to get started.")
                } actions: {
                    Button("Import Goodreads CSV…") { model.isImportingCSV = true }
                }
            } else if shownBooks.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                grid
            }
        }
        .navigationTitle("Library")
        .navigationSubtitle("\(shownBooks.count) books")
        .searchable(text: $search, prompt: "Title or author")
        .toolbar {
            ToolbarItem {
                Picker("Show", selection: $filter) {
                    ForEach(LibraryFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem {
                Menu {
                    Picker("Sort By", selection: $sort) {
                        ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .navigationDestination(for: Book.self) { BookDetailView(book: $0) }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20, alignment: .top)],
                      alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.books) { book in
                            NavigationLink(value: book) {
                                BookCell(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        if !section.title.isEmpty {
                            HStack(alignment: .firstTextBaseline) {
                                Text(section.title).font(.title2.bold())
                                Text("\(section.books.count)").foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .background(.background)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct BookCell: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverImage(book: book)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                .overlay(alignment: .topTrailing) {
                    if book.status == .dnf || book.isPaused {
                        Text(book.status == .dnf ? "DNF" : "On hold")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(5)
                    }
                }
            Text(book.displayTitle)
                .font(.callout.weight(.medium))
                .lineLimit(2)
            if let rating = book.rating {
                StarRating(rating: rating).frame(height: 10)
            }
        }
        .contentShape(Rectangle())
        .help("\(book.displayTitle) — \(book.author)")
    }
}
