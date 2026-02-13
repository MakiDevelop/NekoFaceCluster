import Foundation
import AppKit

/// SearXNG 搜尋結果
struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let url: String
    let imgSrc: String?
    let engine: String
}

/// SearXNG 反向圖搜服務
actor SearXNGService {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    enum SearchError: LocalizedError {
        case invalidURL
        case imageLoadFailed
        case encodingFailed
        case networkError(String)
        case serverError(Int)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "SearXNG URL 格式不正確"
            case .imageLoadFailed: return "無法載入圖片"
            case .encodingFailed: return "圖片編碼失敗"
            case .networkError(let m): return "網路錯誤：\(m)"
            case .serverError(let code): return "伺服器錯誤 \(code)"
            case .decodingFailed: return "回應解析失敗"
            }
        }
    }

    /// 用本地圖片執行反向圖搜
    func search(imagePath: String, baseURL: String) async throws -> [SearchResult] {
        // 1. 載入 + 縮圖
        let jpegData = try loadAndResize(path: imagePath, maxDimension: 300)

        // 2. Base64 data URI
        let b64 = jpegData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(b64)"

        // 3. 建立 POST 請求
        guard let url = URL(string: "\(baseURL)/search") else {
            throw SearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "q", value: dataURI),
            URLQueryItem(name: "engines", value: "tineye"),
            URLQueryItem(name: "format", value: "json"),
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        // 4. 發送
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SearchError.networkError(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw SearchError.serverError(httpResponse.statusCode)
        }

        // 5. 解析 JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            throw SearchError.decodingFailed
        }

        return results.compactMap { item in
            guard let title = item["title"] as? String,
                  let url = item["url"] as? String else { return nil }
            return SearchResult(
                title: title,
                url: url,
                imgSrc: item["img_src"] as? String,
                engine: item["engine"] as? String ?? "tineye"
            )
        }
    }

    // MARK: - 圖片處理

    private func loadAndResize(path: String, maxDimension: CGFloat) throws -> Data {
        guard let nsImage = NSImage(contentsOfFile: path) else {
            throw SearchError.imageLoadFailed
        }

        let originalSize = nsImage.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            throw SearchError.imageLoadFailed
        }

        // 計算縮放尺寸
        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let newSize = NSSize(
            width: round(originalSize.width * scale),
            height: round(originalSize.height * scale)
        )

        // 繪製縮圖
        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resized.unlockFocus()

        // 轉 JPEG
        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw SearchError.encodingFailed
        }

        return jpeg
    }
}
