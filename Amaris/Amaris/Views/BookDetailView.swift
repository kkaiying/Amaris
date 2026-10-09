//
//  BookDetailView.swift
//  Amaris
//
//  One book: cover (with "Choose Cover…"), rating, reading dates, DNF, quotes.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var context

    @State private var isChoosingCover = false
    @State private var coverError: String?
    @State private var isDropTargeted = false

    private var readings: [Reading] {
        (book.readings ?? []).sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private var quotes: [Quote] {
        (book.quotes ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            coverColumn
                .frame(width: 220)
                .padding(24)

            Form {
                Section {
                    LabeledContent("Author", value: book.author)
                    if let series = book.series {
                        LabeledContent("Series", value: series)
                    }
                    if let pages = book.pageCount {
                        LabeledContent("Pages", value: "\(pages)")
                    }
                    LabeledContent("Status") { StatusLabel(status: book.status) }
                    ratingRow
                }

                Section("Reading Dates") {
                    if readings.isEmpty {
                        Text("No reading dates.").foregroundStyle(.secondary)
                    }
                    ForEach(readings) { reading in
                        ReadingDatesRow(reading: reading)
                    }
                    if book.status != .dnf {
                        Button("Mark as DNF", role: .destructive, action: markDNF)
                    }
                }

                Section("Quotes") {
                    if quotes.isEmpty {
                        Text("No quotes yet.").foregroundStyle(.secondary)
                    }
                    ForEach(quotes) { quote in
                        Text(quote.text)
                            .textSelection(.enabled)
                            .padding(.vertical, 2)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .navigationTitle(book.displayTitle)
        .fileImporter(isPresented: $isChoosingCover, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result { setCover(from: url) }
        }
    }

    // MARK: - Cover

    private var coverColumn: some View {
        VStack(spacing: 12) {
            CoverImage(book: book)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 4).stroke(.tint, lineWidth: 3)
                    }
                }
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    setCover(from: url)
                    return true
                } isTargeted: { isDropTargeted = $0 }

            Button("Choose Cover…") { isChoosingCover = true }
            if book.coverSource == .manual {
                Button("Use Goodreads Cover") {
                    // Next sync downloads the Goodreads cover again.
                    book.coverSource = nil
                }
                .buttonStyle(.link)
            }
            if let coverError {
                Text(coverError).font(.caption).foregroundStyle(.red)
            }
            Text("Or drag an image onto the cover.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func setCover(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard CoverStore.normalizedJPEG(data) != nil else {
                coverError = "That file isn't an image."
                return
            }
            try CoverStore.save(data, for: book, source: .manual)
            coverError = nil
        } catch {
            coverError = "Couldn't use that image."
        }
    }

    // MARK: - Rating & status

    private var ratingRow: some View {
        LabeledContent("Rating") {
            HStack(spacing: 8) {
                StarRating(rating: book.rating ?? 0).frame(width: 90, height: 15)
                Text(book.rating.map { $0.formatted() } ?? "Unrated")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
                Stepper("Rating", value: Binding(
                    get: { book.rating ?? 0 },
                    set: { book.rating = $0 == 0 ? nil : $0 }
                ), in: 0...5, step: 0.25)
                .labelsHidden()
            }
        }
    }

    /// Ends the current reading today (or keeps its dates) and marks the book DNF.
    private func markDNF() {
        if let open = book.openReading {
            open.finishedAt = Calendar.current.startOfDay(for: .now)
            open.outcome = .dnf
            open.datesEditedManually = true
        }
        book.status = .dnf
    }
}

private struct StatusLabel: View {
    let status: BookStatus

    var body: some View {
        switch status {
        case .reading: Label("Reading", systemImage: "book")
        case .read: Label("Read", systemImage: "checkmark.circle")
        case .dnf: Label("Did not finish", systemImage: "xmark.circle")
        }
    }
}

/// Editable start/finish dates. Any edit marks the reading as hand-edited,
/// so Goodreads sync never overwrites it.
private struct ReadingDatesRow: View {
    @Bindable var reading: Reading

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(selection: startBinding, displayedComponents: .date) {
                HStack(spacing: 6) {
                    Text("Started")
                    if reading.startIsEstimated {
                        Text("estimated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Guessed from the previous book's finish date. Edit to correct it.")
                    }
                }
            }

            Toggle("Finished", isOn: finishedBinding)

            if reading.finishedAt != nil {
                DatePicker("Finished on", selection: finishBinding,
                           in: (reading.startedAt ?? .distantPast)...,
                           displayedComponents: .date)
                Picker("Outcome", selection: outcomeBinding) {
                    Text("Read").tag(BookStatus.read)
                    Text("Did not finish").tag(BookStatus.dnf)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { reading.startedAt ?? .now },
            set: {
                reading.startedAt = calendar.startOfDay(for: $0)
                reading.startIsEstimated = false
                reading.datesEditedManually = true
            }
        )
    }

    private var finishedBinding: Binding<Bool> {
        Binding(
            get: { reading.finishedAt != nil },
            set: { isFinished in
                reading.finishedAt = isFinished ? max(calendar.startOfDay(for: .now), reading.startedAt ?? .distantPast) : nil
                reading.outcome = isFinished ? (reading.outcome ?? .read) : nil
                reading.datesEditedManually = true
                reading.book?.status = isFinished ? (reading.outcome ?? .read) : .reading
            }
        )
    }

    private var finishBinding: Binding<Date> {
        Binding(
            get: { reading.finishedAt ?? .now },
            set: {
                reading.finishedAt = calendar.startOfDay(for: $0)
                reading.datesEditedManually = true
            }
        )
    }

    private var outcomeBinding: Binding<BookStatus> {
        Binding(
            get: { reading.outcome ?? .read },
            set: {
                reading.outcome = $0
                reading.datesEditedManually = true
                reading.book?.status = $0
            }
        )
    }
}
