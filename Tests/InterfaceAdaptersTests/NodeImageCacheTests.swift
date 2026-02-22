// Background: Image rendering should avoid repeated disk decode while still reflecting file updates.
// Responsibility: Validate NodeImageCache refreshes cached images when file content at the same path changes.
import AppKit
import Foundation
import Testing

@testable import InterfaceAdapters

@Test("NodeImageCache: reloads image when same file path is overwritten")
func test_nodeImageCache_samePathOverwrite_reloadsUpdatedImage() throws {
    let cache = NodeImageCache()
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("png")

    defer {
        try? FileManager.default.removeItem(at: tempURL)
    }

    try writeSolidImage(
        size: CGSize(width: 40, height: 20),
        color: .systemRed,
        to: tempURL,
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    let initialImage = cache.image(atFilePath: tempURL.path)

    try writeSolidImage(
        size: CGSize(width: 120, height: 60),
        color: .systemBlue,
        to: tempURL,
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )

    let updatedImage = cache.image(atFilePath: tempURL.path)

    #expect(initialImage?.size.width == 40)
    #expect(updatedImage?.size.width == 120)
    #expect(updatedImage?.size.height == 60)
}

@Test("NodeImageCache: returns nil after cached file is deleted")
func test_nodeImageCache_deletedFile_returnsNil() throws {
    let cache = NodeImageCache()
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("png")

    try writeSolidImage(
        size: CGSize(width: 30, height: 30),
        color: .systemGreen,
        to: tempURL,
        modifiedAt: Date(timeIntervalSince1970: 1_700_000_200)
    )

    #expect(cache.image(atFilePath: tempURL.path) != nil)

    try FileManager.default.removeItem(at: tempURL)

    #expect(cache.image(atFilePath: tempURL.path) == nil)
}

private func writeSolidImage(
    size: CGSize,
    color: NSColor,
    to url: URL,
    modifiedAt: Date
) throws {
    let image = NSImage(size: size)
    image.lockFocus()
    color.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    image.unlockFocus()

    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw NodeImageCacheTestError.failedToEncodeImage
    }
    try pngData.write(to: url, options: .atomic)
    try FileManager.default.setAttributes(
        [.modificationDate: modifiedAt],
        ofItemAtPath: url.path
    )
}

private enum NodeImageCacheTestError: Error {
    case failedToEncodeImage
}
