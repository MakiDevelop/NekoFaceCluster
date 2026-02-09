import Foundation
@preconcurrency import Vision
import CoreML
import CoreGraphics
import Accelerate

/// ArcFace CoreML 版人臉嵌入器
/// 使用 VNDetectFaceLandmarksRequest 偵測 + 眼睛對齊 + CoreML 推理
public final class CoreMLFaceEmbedder: FaceEmbedder, @unchecked Sendable {

    private let model: VNCoreMLModel
    private let inputSize: CGFloat = 112  // ArcFace 標準輸入

    public init() throws {
        guard let modelURL = Bundle.main.url(forResource: "w600k_r50", withExtension: "mlmodelc") else {
            guard let pkgURL = Bundle.main.url(forResource: "w600k_r50", withExtension: "mlpackage") else {
                throw FaceEmbedderError.internalError("找不到 w600k_r50 模型")
            }
            let compiled = try MLModel.compileModel(at: pkgURL)
            let ml = try MLModel(contentsOf: compiled)
            self.model = try VNCoreMLModel(for: ml)
            print("[CoreMLFaceEmbedder] 模型載入成功（從 mlpackage 編譯）")
            return
        }
        let ml = try MLModel(contentsOf: modelURL)
        self.model = try VNCoreMLModel(for: ml)
        print("[CoreMLFaceEmbedder] 模型載入成功（mlmodelc）")
    }

    public func detectAndEmbed(_ cgImage: CGImage, sourcePath: String) async throws -> [FaceRecord] {
        let observations = try detectFaces(cgImage: cgImage)
        guard !observations.isEmpty else { throw FaceEmbedderError.noFaces }

        var results: [FaceRecord] = []
        results.reserveCapacity(observations.count)

        for obs in observations {
            guard let aligned = alignFace(from: cgImage, observation: obs) else { continue }
            do {
                let embedding = try infer(aligned)
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

    // MARK: - 偵測（含 Landmarks）

    private func detectFaces(cgImage: CGImage) throws -> [VNFaceObservation] {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return request.results ?? []
    }

    // MARK: - 人臉對齊（基於雙眼位置）
    //
    // 重要：Vision 和 CGContext 都用 bottom-left 原點 + Y 軸朝上
    // 所以不需要翻轉 Y 座標

    private func alignFace(from image: CGImage, observation: VNFaceObservation) -> CGImage? {
        guard let landmarks = observation.landmarks,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return simpleCrop(from: image, observation: observation)
        }

        let bbox = observation.boundingBox
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)

        // Vision bbox: 正規化座標，左下原點 — 直接乘圖片尺寸
        // CGContext 也是左下原點，所以不需要翻轉 Y
        let boxX = bbox.origin.x * w
        let boxY = bbox.origin.y * h
        let boxW = bbox.width * w
        let boxH = bbox.height * h

        // Landmark 點相對於 bbox，也是 Y 朝上
        let lc = center(of: leftEye.normalizedPoints)
        let rc = center(of: rightEye.normalizedPoints)

        let leftPx = CGPoint(x: boxX + lc.x * boxW, y: boxY + lc.y * boxH)
        let rightPx = CGPoint(x: boxX + rc.x * boxW, y: boxY + rc.y * boxH)

        // 旋轉角度
        let dx = rightPx.x - leftPx.x
        let dy = rightPx.y - leftPx.y
        let angle = atan2(dy, dx)

        // 縮放：雙眼距離應佔輸出寬度的 ~38%
        let eyeDist = sqrt(dx * dx + dy * dy)
        guard eyeDist > 1 else { return simpleCrop(from: image, observation: observation) }
        let targetDist = inputSize * 0.38
        let scale = targetDist / eyeDist

        // 雙眼中心（原圖座標）
        let eyeCenter = CGPoint(x: (leftPx.x + rightPx.x) / 2,
                                y: (leftPx.y + rightPx.y) / 2)

        // 目標中的眼睛位置（112x112 context，左下原點）
        // 眼睛在距頂部 42% = 距底部 58%
        let targetCenter = CGPoint(x: inputSize / 2, y: inputSize * 0.58)

        // 建立 112x112 context（CGContext 預設左下原點）
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let size = Int(inputSize)
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Affine transform：移到目標中心 → 縮放 → 旋轉 → 移回原圖中心
        ctx.translateBy(x: targetCenter.x, y: targetCenter.y)
        ctx.scaleBy(x: scale, y: scale)
        ctx.rotate(by: -angle)
        ctx.translateBy(x: -eyeCenter.x, y: -eyeCenter.y)

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        return ctx.makeImage()
    }

    private func simpleCrop(from image: CGImage, observation: VNFaceObservation) -> CGImage? {
        let bbox = observation.boundingBox
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)

        // 在 CGImage 座標系（左上原點）做裁切
        let boxW = bbox.width * w
        let boxH = bbox.height * h
        let side = max(boxW, boxH) * 1.4
        let cx = bbox.midX * w
        let cy = (1 - bbox.midY) * h  // 翻轉到 CGImage 的左上原點

        var rect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !rect.isEmpty else { return nil }
        return image.cropping(to: rect)
    }

    private func center(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        return CGPoint(x: sum.x / CGFloat(points.count),
                       y: sum.y / CGFloat(points.count))
    }

    // MARK: - CoreML 推理

    nonisolated(unsafe) private static var loggedOnce = false

    private func infer(_ faceImage: CGImage) throws -> [Float] {
        let request = VNCoreMLRequest(model: self.model)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cgImage: faceImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNCoreMLFeatureValueObservation,
              let multiArray = observation.featureValue.multiArrayValue else {
            throw FaceEmbedderError.featureExtractionFailed
        }

        let count = multiArray.count

        // 首次 log 模型輸出資訊
        if !Self.loggedOnce {
            Self.loggedOnce = true
            print("[CoreMLFaceEmbedder] 輸出維度: \(count), dataType: \(multiArray.dataType.rawValue)")
        }

        // 用 subscript 讀取，自動處理 Float16/Float32/Double
        var floats = [Float](repeating: 0, count: count)
        for i in 0..<count {
            floats[i] = multiArray[i].floatValue
        }

        // L2 正規化（cosine distance 必要）
        var sumSq: Float = 0
        vDSP_svesq(floats, 1, &sumSq, vDSP_Length(count))
        let norm = sqrt(sumSq)
        if norm > 0 {
            var invNorm = 1.0 / norm
            vDSP_vsmul(floats, 1, &invNorm, &floats, 1, vDSP_Length(count))
        }

        return floats
    }

    // MARK: - 座標轉換（給 UI 用，CGImage 左上原點）

    private func pixelRect(from normalizedRect: CGRect,
                           imageWidth: Int, imageHeight: Int) -> CGRect {
        let w = CGFloat(imageWidth)
        let h = CGFloat(imageHeight)
        return CGRect(
            x: normalizedRect.minX * w,
            y: (1 - normalizedRect.maxY) * h,
            width: normalizedRect.width * w,
            height: normalizedRect.height * h
        )
    }
}
