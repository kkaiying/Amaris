//
//  CoverImage.swift
//  Amaris
//
//  Shows a book's cached cover, or a simple placeholder with its title.
//  Shared with the widgets, which can only use locally cached images.
//

import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum CoverStore {
    /// Covers are scaled down to this height: sharp in the app, light for widgets.
    static let maxPixelSize = 900

    /// Saves a cover for a book, replacing any previous file.
    /// Each save gets a new file name so views reload when a cover changes.
    static func save(_ data: Data, for book: Book, source: CoverSource) throws {
        let unique = UUID().uuidString.prefix(8)
        let fileName = "\(book.goodreadsID ?? UUID().uuidString)-\(source.rawValue)-\(unique).jpg"
        let url = AmarisStore.coversDirectory.appending(path: fileName)
        try (normalizedJPEG(data) ?? data).write(to: url, options: .atomic)

        if let old = book.coverFileName, old != fileName {
            try? FileManager.default.removeItem(at: AmarisStore.coversDirectory.appending(path: old))
        }
        book.coverFileName = fileName
        book.coverSource = source
    }

    /// Downscales an image to `maxPixelSize` and re-encodes it as JPEG.
    /// Returns nil if the data isn't a readable image.
    nonisolated static func normalizedJPEG(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    static func url(for book: Book) -> URL? {
        book.coverFileName.map { AmarisStore.coversDirectory.appending(path: $0) }
    }

    static func hasCover(for book: Book) -> Bool {
        guard let url = url(for: book) else { return false }
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
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
        return UIImage(contentsOfFile: url.path(percentEncoded: false)).map(Image.init(uiImage:))
        #endif
    }
}
