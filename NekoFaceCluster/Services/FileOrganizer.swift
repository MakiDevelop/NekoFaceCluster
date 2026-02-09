import Foundation

/// 將分群結果整理到輸出目錄
struct FileOrganizer {
    enum Mode {
        case move
        case copy
        case symlink
    }

    static func organize(
        clusters: [PersonCluster],
        noisePaths: [String],
        to outputDir: URL,
        mode: Mode
    ) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

        for cluster in clusters {
            let personDir = outputDir.appendingPathComponent(cluster.name)
            try fm.createDirectory(at: personDir, withIntermediateDirectories: true)

            for path in cluster.imagePaths {
                let srcURL = URL(fileURLWithPath: path)
                let dstURL = personDir.appendingPathComponent(srcURL.lastPathComponent)
                if fm.fileExists(atPath: dstURL.path) { continue }

                switch mode {
                case .move:
                    try fm.moveItem(at: srcURL, to: dstURL)
                case .copy:
                    try fm.copyItem(at: srcURL, to: dstURL)
                case .symlink:
                    try fm.createSymbolicLink(at: dstURL, withDestinationURL: srcURL)
                }
            }
        }

        if !noisePaths.isEmpty {
            let noiseDir = outputDir.appendingPathComponent("_Uncategorized")
            try fm.createDirectory(at: noiseDir, withIntermediateDirectories: true)

            for path in noisePaths {
                let srcURL = URL(fileURLWithPath: path)
                let dstURL = noiseDir.appendingPathComponent(srcURL.lastPathComponent)
                if fm.fileExists(atPath: dstURL.path) { continue }

                switch mode {
                case .move:
                    try fm.moveItem(at: srcURL, to: dstURL)
                case .copy:
                    try fm.copyItem(at: srcURL, to: dstURL)
                case .symlink:
                    try fm.createSymbolicLink(at: dstURL, withDestinationURL: srcURL)
                }
            }
        }

        // JSON Report
        let report: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "total_persons": clusters.count,
            "total_categorized": clusters.reduce(0) { $0 + $1.imagePaths.count },
            "total_uncategorized": noisePaths.count,
            "persons": clusters.map { ["name": $0.name, "count": $0.imagePaths.count] }
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputDir.appendingPathComponent("report.json"))
    }
}
