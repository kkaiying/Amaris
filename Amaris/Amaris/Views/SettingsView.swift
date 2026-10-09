//
//  SettingsView.swift
//  Amaris
//
//  Settings window (⌘,): Goodreads account and CSV import.
//

import SwiftUI

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
