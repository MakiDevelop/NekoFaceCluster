import Foundation
import CoreGraphics

/// 單一臉的向量化結果
public struct FaceRecord: Sendable, Identifiable {
    public let id = UUID()
    public let embedding: [Float]
    public let boundingBox: CGRect      // 原圖像素座標
    public let confidence: Float        // 偵測信度 0~1
    public let sourceImagePath: String  // 來源圖片路徑
}

/// 抽象化的人臉嵌入器 — 未來可切換 ArcFace CoreML 版
public protocol FaceEmbedder: Sendable {
    func detectAndEmbed(_ cgImage: CGImage, sourcePath: String) async throws -> [FaceRecord]
}

/// 共通錯誤型別
public enum FaceEmbedderError: Error, LocalizedError {
    case noFaces
    case featureExtractionFailed
    case imageLoadFailed(String)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .noFaces: return "No faces detected in image."
        case .featureExtractionFailed: return "Failed to extract face features."
        case .imageLoadFailed(let path): return "Failed to load image: \(path)"
        case .internalError(let msg): return msg
        }
    }
}
