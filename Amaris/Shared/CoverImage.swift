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

    /// Thumbnails decoded once and reused. A year calendar shows hundreds of
    /// small covers, so full-size images would use far too much memory.
    nonisolated(unsafe) private static let thumbnails = NSCache<NSString, CGImage>()

    static func thumbnail(for book: Book, maxPixelSize: Int) -> CGImage? {
        thumbnail(fileName: book.coverFileName, maxPixelSize: maxPixelSize)
    }

    static func thumbnail(fileName: String?, maxPixelSize: Int) -> CGImage? {
        guard let fileName else { return nil }
        let url = AmarisStore.coversDirectory.appending(path: fileName)
        let key = "\(fileName)@\(maxPixelSize)" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        thumbnails.setObject(image, forKey: key)
        return image
    }
}

/// A book cover at 2:3, or a placeholder with the title.
struct CoverImage: View {
    let book: Book
    /// Decode size; the default suits the library grid and book pages.
    var maxPixelSize = 600

    var body: some View {
        CoverArt(book: book, maxPixelSize: maxPixelSize)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// The cover filling whatever space it's given (cropped), e.g. a calendar day.
struct CoverArt: View {
    let fileName: String?
    let title: String
    var maxPixelSize = 600

    init(book: Book, maxPixelSize: Int = 600) {
        self.init(fileName: book.coverFileName, title: book.displayTitle, maxPixelSize: maxPixelSize)
    }

    init(fileName: String?, title: String, maxPixelSize: Int = 600) {
        self.fileName = fileName
        self.title = title
        self.maxPixelSize = maxPixelSize
    }

    var body: some View {
        if let image = CoverStore.thumbnail(fileName: fileName, maxPixelSize: maxPixelSize) {
            Color.clear
                .overlay {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipped()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}
