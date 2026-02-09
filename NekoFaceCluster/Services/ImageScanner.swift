import Foundation
import AppKit

/// 遞迴掃描目錄中的圖片檔案
struct ImageScanner {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "webp", "bmp", "tiff"
    ]

    static func scan(directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func loadCGImage(from url: URL) -> CGImage? {
        guard let nsImage = NSImage(contentsOf: url) else { return nil }
        return nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
