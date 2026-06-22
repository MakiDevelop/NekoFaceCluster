import Foundation
import AppKit

/// 遞迴掃描目錄中的圖片檔案（含子資料夾）
struct ImageScanner {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "webp", "bmp", "tiff"
    ]

    static func scan(directory: URL) -> [URL] {
        var results: [URL] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
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
