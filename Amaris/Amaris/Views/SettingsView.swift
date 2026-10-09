//
//  SettingsView.swift
//  Amaris
//
//  Settings window (⌘,): Goodreads account and CSV import.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var profileText = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                if let userID = model.goodreads.userID {
                    LabeledContent("Connected account", value: "User \(userID)")
                    Button("Disconnect", role: .destructive) {
                        model.goodreads.userID = nil
                    }
                } else {
                    TextField("Profile link", text: $profileText,
                              prompt: Text("https://www.goodreads.com/user/show/…"))
                    Button("Connect") {
                        if let id = GoodreadsFeed.userID(from: profileText) {
                            model.goodreads.userID = id
                            error = nil
                        } else {
                            error = "That doesn't look like a Goodreads profile link."
                        }
                    }
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Goodreads")
            } footer: {
                Text("Your shelves must be public. Amaris reads your currently-reading, read and did-not-finish shelves on launch and every hour.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(AmarisTheme.allCases, id: \.self) { theme in
                    FanArtRow(theme: theme)
                }
            } header: {
                Text("Quote Widget Fan Art")
            } footer: {
                Text("Shown faintly behind the quote widget in each theme. Images stay on this Mac.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Import Goodreads CSV…") { model.isImportingCSV = true }
                Button("Import Start Dates from Goodreads Page…") { model.isImportingShelfPage = true }
            } header: {
                Text("Import")
            } footer: {
                Text("CSV: Goodreads → My Books → Import and export → Export Library. The export has no start dates, so for those save your Read shelf in table view (with the \u{201C}date started\u{201D} column) as HTML and import that page. Both are safe to run again: nothing is duplicated and your edits are kept.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Pick, preview or remove the fan art for one theme.
private struct FanArtRow: View {
    let theme: AmarisTheme
    @State private var isPicking = false
    @State private var preview: CGImage?
    @State private var error: String?

    var body: some View {
        LabeledContent(theme.displayName) {
            HStack(spacing: 10) {
                if let preview {
                    Image(decorative: preview, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Button("Remove", role: .destructive) {
                        FanArtStore.remove(for: theme)
                        refresh()
                    }
                }
                Button(preview == nil ? "Choose Image…" : "Change…") { isPicking = true }
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.image]) { result in
            guard case .success(let url) = result else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                try FanArtStore.save(try Data(contentsOf: url), for: theme)
                error = nil
            } catch {
                self.error = "Couldn't use that image."
            }
            refresh()
        }
        .onAppear { preview = FanArtStore.image(for: theme) }
        .help(error ?? "")
    }

    private func refresh() {
        preview = FanArtStore.image(for: theme)
        WidgetData.reloadWidgets()
    }
}
