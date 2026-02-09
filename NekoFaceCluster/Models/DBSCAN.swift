import Foundation
import Accelerate

/// DBSCAN clustering（cosine distance + Accelerate 加速）
public struct DBSCAN {
    public let eps: Float
    public let minSamples: Int

    public init(eps: Float = 0.45, minSamples: Int = 3) {
        self.eps = eps
        self.minSamples = max(1, minSamples)
    }

    /// 回傳每個點的 cluster label（-1 = noise）
    public func fit(embeddings: [[Float]]) -> [Int] {
        let n = embeddings.count
        guard n > 0 else { return [] }
        let dims = embeddings[0].count

        // L2 正規化 → cosine distance = 1 - dot
        var normalized = embeddings
        for i in 0..<n {
            var norm: Float = 0
            vDSP_svesq(embeddings[i], 1, &norm, vDSP_Length(dims))
            norm = sqrtf(norm) + 1e-12
            vDSP_vsdiv(embeddings[i], 1, &norm, &normalized[i], 1, vDSP_Length(dims))
        }

        // 預計算距離矩陣
        let distMatrix = buildDistanceMatrix(vectors: normalized)

        var labels = Array(repeating: -2, count: n)
        var clusterId = 0

        for i in 0..<n where labels[i] == -2 {
            let neighbors = regionQuery(index: i, distMatrix: distMatrix, n: n)
            if neighbors.count < minSamples {
                labels[i] = -1
                continue
            }

            labels[i] = clusterId
            var seeds = Array(neighbors)

            while !seeds.isEmpty {
                let j = seeds.removeLast()
                if labels[j] == -1 { labels[j] = clusterId }
                if labels[j] != -2 { continue }
                labels[j] = clusterId

                let jNeighbors = regionQuery(index: j, distMatrix: distMatrix, n: n)
                if jNeighbors.count >= minSamples {
                    for k in jNeighbors where labels[k] == -2 || labels[k] == -1 {
                        seeds.append(k)
                    }
                }
            }
            clusterId += 1
        }

        return labels
    }

    // MARK: - Distance Matrix (Accelerate vDSP)

    private func buildDistanceMatrix(vectors: [[Float]]) -> [Float] {
        let n = vectors.count
        var matrix = [Float](repeating: 0, count: n * n)

        for i in 0..<n {
            for j in (i + 1)..<n {
                var dot: Float = 0
                vectors[i].withUnsafeBufferPointer { lp in
                    vectors[j].withUnsafeBufferPointer { rp in
                        vDSP_dotpr(lp.baseAddress!, 1,
                                   rp.baseAddress!, 1,
                                   &dot, vDSP_Length(vectors[i].count))
                    }
                }
                let dist = 1 - dot
                matrix[i * n + j] = dist
                matrix[j * n + i] = dist
            }
        }
        return matrix
    }

    private func regionQuery(index: Int, distMatrix: [Float], n: Int) -> [Int] {
        var neighbors: [Int] = []
        neighbors.reserveCapacity(16)
        let offset = index * n
        for j in 0..<n where j != index {
            if distMatrix[offset + j] <= eps {
                neighbors.append(j)
            }
        }
        return neighbors
    }
}
