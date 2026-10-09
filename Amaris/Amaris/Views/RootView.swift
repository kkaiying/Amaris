//
//  RootView.swift
//  Amaris
//
//  Main window: sidebar with Library / Quotes / Calendar.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum SidebarItem: Hashable, CaseIterable {
    case library, quotes, calendar

    var title: String {
        switch self {
        case .library: "Library"
        case .quotes: "Quotes"
        case .calendar: "Calendar"
        }
    }

    var systemImage: String {
        switch self {
        case .library: "books.vertical"
        case .quotes: "quote.opening"
        case .calendar: "calendar"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var selection: SidebarItem? = .library

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
            .safeAreaInset(edge: .bottom) { SyncStatusView() }
        } detail: {
            NavigationStack {
                switch selection ?? .library {
                case .library:
                    LibraryView()
                case .quotes:
                    QuotesView()
                case .calendar:
                    CalendarView()
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
        // Sync on launch and hourly while the window is open; restarts when
        // the Goodreads account changes.
        .task(id: model.goodreads.userID) {
            await model.syncPeriodically(in: context)
        }
        .sheet(isPresented: $model.isAddingQuotes) {
            AddQuotesSheet(initialBook: model.addQuotesBook)
        }
        .fileImporter(isPresented: $model.isImportingCSV,
                      allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            Task { await model.importCSV(from: url, into: context) }
        }
        .fileImporter(isPresented: $model.isImportingShelfPage, allowedContentTypes: [.html]) { result in
            guard case .success(let url) = result else { return }
            model.importStartDates(from: url, into: context)
        }
    }
}

/// Sidebar footer: sync status and a manual sync button.
private struct SyncStatusView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.goodreads.userID == nil {
                Text("Connect Goodreads to sync your shelves.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SettingsLink { Text("Open Settings…") }
                    .controlSize(.small)
            } else {
                HStack(spacing: 6) {
                    if model.isBusy {
                        ProgressView().controlSize(.mini)
                    }
                    Text(model.statusText ?? "Not synced yet")
                        .font(.caption)
                        .foregroundStyle(model.goodreads.lastError == nil ? Color.secondary : Color.red)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button {
                        Task { await model.syncNow(in: context) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.isBusy)
                    .help("Sync with Goodreads now")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
