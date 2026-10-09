//
//  CoverImage.swift
//  Amaris
//
//  Shows a book's cached cover, or a simple placeholder with its title.
//  Shared with the widgets, which can only use locally cached images.
//

import SwiftUI

enum CoverStore {
    static func fileName(for book: Book) -> String {
        "\(book.goodreadsID ?? UUID().uuidString).jpg"
    }

    static func url(for book: Book) -> URL? {
        book.coverFileName.map { AmarisStore.coversDirectory.appending(path: $0) }
    }

    static func hasCover(for book: Book) -> Bool {
        guard let url = url(for: book) else { return false }
        return FileManager.default.fileExists(atPath: url.path())
    }
}

struct CoverImage: View {
    let book: Book

    var body: some View {
        Group {
            if let image = loadImage() {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(.quaternary)
            Text(book.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(4)
        }
    }

    private func loadImage() -> Image? {
        guard let url = CoverStore.url(for: book) else { return nil }
        #if canImport(AppKit)
        return NSImage(contentsOf: url).map(Image.init(nsImage:))
        #else
        return UIImage(contentsOfFile: url.path()).map(Image.init(uiImage:))
        #endif
    }
}
