import Foundation
import AppKit

/// 搜尋結果
struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let url: String
    let imgSrc: String?
    let engine: String
}

/// 反向圖搜服務（Yandex 瀏覽器開啟 + SearXNG TinEye 備用）
actor ReverseImageSearchService {

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    enum SearchError: LocalizedError {
        case imageLoadFailed
        case encodingFailed
        case uploadFailed(String)
        case networkError(String)
        case serverError(Int)
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .imageLoadFailed: return "無法載入圖片"
            case .encodingFailed: return "圖片編碼失敗"
            case .uploadFailed(let m): return "圖片上傳失敗：\(m)"
            case .networkError(let m): return "網路錯誤：\(m)"
            case .serverError(let code): return "伺服器錯誤 \(code)"
            case .decodingFailed: return "回應解析失敗"
            }
        }
    }

    /// 上傳圖片到 0x0.st 取得臨時 URL，再開瀏覽器 Yandex 搜
    func openInBrowser(imagePath: String) async throws -> URL {
        let jpegData = try loadAndResize(path: imagePath, maxDimension: 500)

        // 上傳到 0x0.st
        let imageURL = try await uploadToTemp(jpegData: jpegData)

        // 組 Yandex 反向圖搜 URL
        let encoded = imageURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageURL.absoluteString
        guard let searchURL = URL(string: "https://yandex.com/images/search?rpt=imageview&url=\(encoded)") else {
            throw SearchError.uploadFailed("無法組成搜尋 URL")
        }

        return searchURL
    }

    /// SearXNG TinEye 搜尋（備用）
    func searchViaSearXNG(imagePath: String, baseURL: String) async throws -> [SearchResult] {
        let jpegData = try loadAndResize(path: imagePath, maxDimension: 300)

        let b64 = jpegData.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(b64)"

        guard let url = URL(string: "\(baseURL)/search") else {
            throw SearchError.networkError("SearXNG URL 格式不正確")
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

    // MARK: - 圖片上傳

    private func uploadToTemp(jpegData: Data) async throws -> URL {
        guard let uploadURL = URL(string: "https://litterbox.catbox.moe/resources/internals/api.php") else {
            throw SearchError.uploadFailed("無效的上傳 URL")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // reqtype
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"reqtype\"\r\n\r\n".data(using: .utf8)!)
        body.append("fileupload".data(using: .utf8)!)
        // time (1h 足夠搜尋用)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"time\"\r\n\r\n".data(using: .utf8)!)
        body.append("1h".data(using: .utf8)!)
        // file
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"face.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw SearchError.uploadFailed(error.localizedDescription)
        }

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw SearchError.uploadFailed("HTTP \(httpResponse.statusCode)")
        }

        guard let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let imageURL = URL(string: urlString) else {
            throw SearchError.uploadFailed("回應格式錯誤")
        }

        return imageURL
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

        let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height, 1.0)
        let newSize = NSSize(
            width: round(originalSize.width * scale),
            height: round(originalSize.height * scale)
        )

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        nsImage.draw(in: NSRect(origin: .zero, size: newSize))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw SearchError.encodingFailed
        }

        return jpeg
    }
}
