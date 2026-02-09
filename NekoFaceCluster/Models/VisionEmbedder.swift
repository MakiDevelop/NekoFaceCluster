import Foundation
@preconcurrency import Vision
import CoreGraphics
import Accelerate

/// Vision Framework 版 FaceEmbedder
/// 使用 VNDetectFaceRectanglesRequest + VNGenerateImageFeaturePrintRequest
public struct VisionEmbedder: FaceEmbedder {

    private let paddingRatio: CGFloat

    public init(paddingRatio: CGFloat = 0.15) {
        self.paddingRatio = paddingRatio
    }

    public func detectAndEmbed(_ cgImage: CGImage, sourcePath: String) async throws -> [FaceRecord] {
        let observations = try await detectFaces(cgImage: cgImage)
        guard !observations.isEmpty else { throw FaceEmbedderError.noFaces }

        var results: [FaceRecord] = []
        results.reserveCapacity(observations.count)

        for obs in observations {
            guard let faceCrop = cropFace(from: cgImage, observation: obs) else { continue }
            do {
                let embedding = try generateFeaturePrint(cgImage: faceCrop)
                let bbox = pixelRect(from: obs.boundingBox,
                                     imageWidth: cgImage.width,
                                     imageHeight: cgImage.height)
                results.append(FaceRecord(
                    embedding: embedding,
                    boundingBox: bbox,
                    confidence: obs.confidence,
                    sourceImagePath: sourcePath
                ))
            } catch {
                continue
            }
        }

        guard !results.isEmpty else { throw FaceEmbedderError.featureExtractionFailed }
        return results
    }

    // MARK: - Vision Requests

    private func detectFaces(cgImage: CGImage) async throws -> [VNFaceObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let obs = request.results as? [VNFaceObservation] ?? []
                continuation.resume(returning: obs)
            }
            request.revision = VNDetectFaceRectanglesRequestRevision3

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    // completion handler 會負責 resume，這裡不需要
                } catch {
                    // perform 拋錯時 completion handler 不會被呼叫，安全 resume
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func generateFeaturePrint(cgImage: CGImage) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw FaceEmbedderError.featureExtractionFailed
        }

        return try extractFloats(from: observation)
    }

    /// 從 VNFeaturePrintObservation 取出 Float 陣列
    /// 支援 .float 和 .float16 兩種 elementType（macOS 14+ 可能回傳 float16）
    private func extractFloats(from observation: VNFeaturePrintObservation) throws -> [Float] {
        let count = observation.elementCount
        var floats = [Float](repeating: 0, count: count)

        let data = observation.data
        switch observation.elementType {
        case .float:
            data.withUnsafeBytes { rawBuffer in
                let buffer = rawBuffer.bindMemory(to: Float.self)
                for i in 0..<min(count, buffer.count) {
                    floats[i] = buffer[i]
                }
            }
        case .double:
            data.withUnsafeBytes { rawBuffer in
                let buffer = rawBuffer.bindMemory(to: Double.self)
                for i in 0..<min(count, buffer.count) {
                    floats[i] = Float(buffer[i])
                }
            }
        default:
            // float16 (UInt16) — 用 Accelerate 轉換
            data.withUnsafeBytes { rawBuffer in
                let srcBuffer = rawBuffer.bindMemory(to: UInt16.self)
                var src = Array(srcBuffer.prefix(count))
                src.withUnsafeMutableBufferPointer { srcPtr in
                    floats.withUnsafeMutableBufferPointer { dstPtr in
                        let pixelCount = vImagePixelCount(count)
                        var srcBuf = vImage_Buffer(
                            data: srcPtr.baseAddress!,
                            height: 1, width: pixelCount,
                            rowBytes: count * 2
                        )
                        var dstBuf = vImage_Buffer(
                            data: dstPtr.baseAddress!,
                            height: 1, width: pixelCount,
                            rowBytes: count * 4
                        )
                        vImageConvert_Planar16FtoPlanarF(&srcBuf, &dstBuf, vImage_Flags(kvImageNoFlags))
                    }
                }
            }
        }

        // 確認不是全零向量（embedding 提取失敗的跡象）
        let hasNonZero = floats.contains { $0 != 0 }
        guard hasNonZero else {
            throw FaceEmbedderError.featureExtractionFailed
        }

        return floats
    }

    // MARK: - Helpers

    private func cropFace(from cgImage: CGImage, observation: VNFaceObservation) -> CGImage? {
        let rect = pixelRect(from: observation.boundingBox,
                             imageWidth: cgImage.width,
                             imageHeight: cgImage.height)
        return cgImage.cropping(to: rect)
    }

    private func pixelRect(from normalizedRect: CGRect,
                           imageWidth: Int,
                           imageHeight: Int) -> CGRect {
        let w = CGFloat(imageWidth)
        let h = CGFloat(imageHeight)

        var rect = CGRect(
            x: normalizedRect.minX * w,
            y: (1 - normalizedRect.maxY) * h,
            width: normalizedRect.width * w,
            height: normalizedRect.height * h
        )

        let padX = rect.width * paddingRatio
        let padY = rect.height * paddingRatio
        rect = rect.insetBy(dx: -padX, dy: -padY)

        rect.origin.x = max(0, rect.origin.x)
        rect.origin.y = max(0, rect.origin.y)
        rect.size.width = min(rect.width, w - rect.origin.x)
        rect.size.height = min(rect.height, h - rect.origin.y)

        return rect
    }
}
