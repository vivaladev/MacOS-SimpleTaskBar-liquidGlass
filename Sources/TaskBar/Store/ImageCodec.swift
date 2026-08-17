import AppKit
import Foundation
import UniformTypeIdentifiers

enum ImageCodec {
    static let maxEdge: CGFloat = 1280
    static let jpegQuality: CGFloat = 0.72
    static let maxAttachments = 6

    static func jpegData(from image: NSImage) -> Data? {
        guard let resized = resized(image, maxEdge: maxEdge) else { return nil }
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: jpegQuality])
    }

    static func jpegData(from url: URL) -> Data? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return jpegData(from: image)
    }

    static func jpegData(from pasteboard: NSPasteboard) -> [Data] {
        var result: [Data] = []

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for image in images {
                if let data = jpegData(from: image) {
                    result.append(data)
                }
            }
        }

        if result.isEmpty, let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where isImageFile(url) {
                if let data = jpegData(from: url) {
                    result.append(data)
                }
            }
        }

        return result
    }

    static func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "gif", "webp", "heic", "tif", "tiff", "bmp"].contains(ext)
    }

    private static func resized(_ image: NSImage, maxEdge: CGFloat) -> NSImage? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        if longest <= maxEdge { return image }

        let scale = maxEdge / longest
        let target = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let output = NSImage(size: target)
        output.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        output.unlockFocus()
        return output
    }
}
