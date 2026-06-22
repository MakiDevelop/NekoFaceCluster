import SwiftUI

/// 分群結果中的一個人
struct PersonCluster: Identifiable {
    let id: Int
    var name: String
    var imagePaths: [String]
    var thumbnailPath: String? { imagePaths.first }
}

/// 處理階段
enum ProcessingPhase: String {
    case idle = "等待選擇資料夾"
    case scanning = "掃描圖片中..."
    case embedding = "辨識人臉中..."
    case clustering = "分群中..."
    case reviewing = "審核分群結果"
    case organizing = "整理檔案中..."
    case done = "完成"
    case error = "發生錯誤"
}

@MainActor
class AppState: ObservableObject {
    @Published var inputDirectory: URL?
    @Published var outputDirectory: URL?

    @Published var phase: ProcessingPhase = .idle
    @Published var progress: Double = 0
    @Published var currentFile: String = ""
    @Published var statusMessage: String = ""

    @Published var totalImages: Int = 0
    @Published var processedImages: Int = 0
    @Published var totalFaces: Int = 0
    @Published var noFaceImages: Int = 0
    @Published var errorImages: Int = 0

    @Published var clusters: [PersonCluster] = []
    @Published var noisePaths: [String] = []

    @Published var eps: Double = 0.45
    @Published var minSamples: Int = 2
    @Published var fileMode: FileMode = .move

    // MARK: - SearXNG 圖搜

    @Published var searxngBaseURL: String {
        didSet { UserDefaults.standard.set(searxngBaseURL, forKey: "searxngBaseURL") }
    }
    @Published var searchingClusterId: Int?
    @Published var isSearching: Bool = false
    @Published var searchResults: [SearchResult] = []
    @Published var searchError: String?

    // Task handle for long-running processing (cancel support)
    private var _processingTask: Task<Void, Never>?

    func setProcessingTask(_ task: Task<Void, Never>?) {
        _processingTask?.cancel()
        _processingTask = task
    }

    func cancelProcessing() {
        _processingTask?.cancel()
        _processingTask = nil
        if isProcessing {
            phase = .error
            statusMessage = "處理已取消"
        }
    }

    enum FileMode: String, CaseIterable, Identifiable {
        case move = "移動"
        case copy = "複製"
        case symlink = "Symlink"
        var id: String { rawValue }
    }

    init() {
        self.searxngBaseURL = UserDefaults.standard.string(forKey: "searxngBaseURL")
            ?? "https://erika.n1k.tw/searxng"
    }

    var isProcessing: Bool {
        switch phase {
        case .scanning, .embedding, .clustering, .organizing: return true
        default: return false
        }
    }

    /// 是否在審核階段（可編輯分群）
    var isReviewing: Bool { phase == .reviewing }

    func renameCluster(id: Int, to newName: String) {
        if let index = clusters.firstIndex(where: { $0.id == id }) {
            clusters[index].name = newName
        }
    }

    /// 從分群中移除圖片，放回未分類
    func removeImage(_ path: String, fromCluster clusterId: Int) {
        if let index = clusters.firstIndex(where: { $0.id == clusterId }) {
            clusters[index].imagePaths.removeAll { $0 == path }
            noisePaths.append(path)
            if clusters[index].imagePaths.isEmpty {
                clusters.remove(at: index)
            }
        }
    }

    /// 移除整個分群，所有圖片放回未分類
    func removeCluster(id: Int) {
        if let index = clusters.firstIndex(where: { $0.id == id }) {
            noisePaths.append(contentsOf: clusters[index].imagePaths)
            clusters.remove(at: index)
        }
    }

    // MARK: - 圖搜操作

    /// 開瀏覽器 Yandex 反向搜圖（辨人臉主力）
    func openBrowserSearch(for clusterId: Int) {
        guard let cluster = clusters.first(where: { $0.id == clusterId }),
              let imagePath = cluster.thumbnailPath else { return }
        searchingClusterId = clusterId
        isSearching = true
        searchError = nil

        Task {
            let service = ReverseImageSearchService()
            do {
                let searchURL = try await service.openInBrowser(imagePath: imagePath)
                isSearching = false
                NSWorkspace.shared.open(searchURL)
            } catch {
                isSearching = false
                searchError = error.localizedDescription
            }
        }
    }

    /// SearXNG TinEye 搜尋（備用，找相同圖片來源）
    func startTinEyeSearch(for clusterId: Int) {
        guard let cluster = clusters.first(where: { $0.id == clusterId }),
              let imagePath = cluster.thumbnailPath else { return }
        searchingClusterId = clusterId
        isSearching = true
        searchResults = []
        searchError = nil

        Task {
            let service = ReverseImageSearchService()
            do {
                let results = try await service.searchViaSearXNG(imagePath: imagePath, baseURL: searxngBaseURL)
                isSearching = false
                searchResults = results
                if results.isEmpty { searchError = "沒有找到結果" }
            } catch {
                isSearching = false
                searchError = error.localizedDescription
            }
        }
    }

    func applySearchName(_ name: String, toCluster clusterId: Int) {
        renameCluster(id: clusterId, to: name)
        dismissSearch()
    }

    func dismissSearch() {
        searchingClusterId = nil
        isSearching = false
        searchResults = []
        searchError = nil
    }

    func reset() {
        phase = .idle
        progress = 0
        currentFile = ""
        statusMessage = ""
        totalImages = 0
        processedImages = 0
        totalFaces = 0
        noFaceImages = 0
        errorImages = 0
        clusters = []
        noisePaths = []
    }
}
