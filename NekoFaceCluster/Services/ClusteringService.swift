import Foundation

/// 協調整個 pipeline：掃描 → 嵌入 → 分群
actor ClusteringService {
    private let embedder: FaceEmbedder
    private let dbscan: DBSCAN

    init(embedder: FaceEmbedder? = nil, eps: Float = 0.45, minSamples: Int = 3) {
        // 優先使用 CoreML ArcFace，fallback 到 Vision FeaturePrint
        if let embedder {
            self.embedder = embedder
        } else {
            do {
                self.embedder = try CoreMLFaceEmbedder()
            } catch {
                print("CoreML 模型載入失敗，fallback 到 VisionEmbedder: \(error)")
                self.embedder = VisionEmbedder()
            }
        }
        self.dbscan = DBSCAN(eps: eps, minSamples: minSamples)
    }

    struct ProcessResult {
        let clusters: [PersonCluster]
        let noisePaths: [String]
        let totalFaces: Int
        let noFaceCount: Int
        let errorCount: Int
    }

    struct ProgressInfo: Sendable {
        let processed: Int
        let total: Int
        let file: String
        let totalFaces: Int
        let noFaceCount: Int
        let errorCount: Int
    }

    func process(
        imageURLs: [URL],
        onProgress: @Sendable @MainActor (ProgressInfo) -> Void
    ) async throws -> ProcessResult {
        if Task.isCancelled {
            return ProcessResult(clusters: [], noisePaths: [], totalFaces: 0, noFaceCount: 0, errorCount: 0)
        }

        var allRecords: [FaceRecord] = []
        var noFaceCount = 0
        var errorCount = 0
        let total = imageURLs.count
        var completed = 0

        // Capture Sendable embedder under actor isolation before launching concurrent children.
        let embedder = self.embedder

        // Parallel embedding: images are independent. Use TaskGroup for concurrency.
        await withTaskGroup(of: (records: [FaceRecord], noFace: Int, error: Int, fileName: String).self) { group in
            for url in imageURLs {
                let fileName = url.lastPathComponent
                group.addTask {
                    guard let cgImage = ImageScanner.loadCGImage(from: url) else {
                        return ([], 0, 1, fileName)
                    }
                    do {
                        let records = try await embedder.detectAndEmbed(cgImage, sourcePath: url.path)
                        return (records, 0, 0, fileName)
                    } catch FaceEmbedderError.noFaces {
                        return ([], 1, 0, fileName)
                    } catch {
                        return ([], 0, 1, fileName)
                    }
                }
            }

            for await item in group {
                allRecords.append(contentsOf: item.records)
                noFaceCount += item.noFace
                errorCount += item.error
                completed += 1

                await onProgress(ProgressInfo(
                    processed: completed,
                    total: total,
                    file: item.fileName,
                    totalFaces: allRecords.count,
                    noFaceCount: noFaceCount,
                    errorCount: errorCount
                ))
            }
        }

        guard !allRecords.isEmpty else {
            return ProcessResult(clusters: [], noisePaths: [], totalFaces: 0,
                                 noFaceCount: noFaceCount, errorCount: errorCount)
        }

        let embeddings = allRecords.map { $0.embedding }
        let labels = dbscan.fit(embeddings: embeddings)

        var clusterMap: [Int: [String]] = [:]
        var noisePaths: [String] = []

        for (index, label) in labels.enumerated() {
            let path = allRecords[index].sourceImagePath
            if label == -1 {
                noisePaths.append(path)
            } else {
                clusterMap[label, default: []].append(path)
            }
        }

        let clusters = clusterMap
            .sorted { $0.key < $1.key }
            .map { (label, paths) in
                PersonCluster(
                    id: label,
                    name: "Person \(label + 1)",
                    imagePaths: Array(Set(paths)).sorted()
                )
            }

        return ProcessResult(
            clusters: clusters,
            noisePaths: Array(Set(noisePaths)).sorted(),
            totalFaces: allRecords.count,
            noFaceCount: noFaceCount,
            errorCount: errorCount
        )
    }
}
