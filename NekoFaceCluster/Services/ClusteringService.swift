import Foundation

/// 協調整個 pipeline：掃描 → 嵌入 → 分群
actor ClusteringService {
    private let embedder: FaceEmbedder
    private let dbscan: DBSCAN

    init(embedder: FaceEmbedder = VisionEmbedder(), eps: Float = 0.45, minSamples: Int = 3) {
        self.embedder = embedder
        self.dbscan = DBSCAN(eps: eps, minSamples: minSamples)
    }

    struct ProcessResult {
        let clusters: [PersonCluster]
        let noisePaths: [String]
        let totalFaces: Int
        let noFaceCount: Int
        let errorCount: Int
    }

    func process(
        imageURLs: [URL],
        onProgress: @Sendable @MainActor (Int, Int, String) -> Void
    ) async throws -> ProcessResult {
        var allRecords: [FaceRecord] = []
        var noFaceCount = 0
        var errorCount = 0
        let total = imageURLs.count

        for (index, url) in imageURLs.enumerated() {
            let fileName = url.lastPathComponent
            await onProgress(index + 1, total, fileName)

            guard let cgImage = ImageScanner.loadCGImage(from: url) else {
                errorCount += 1
                continue
            }

            do {
                let records = try await embedder.detectAndEmbed(cgImage, sourcePath: url.path)
                allRecords.append(contentsOf: records)
            } catch FaceEmbedderError.noFaces {
                noFaceCount += 1
            } catch {
                errorCount += 1
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
