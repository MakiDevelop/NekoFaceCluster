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
    @Published var minSamples: Int = 3
    @Published var fileMode: FileMode = .symlink

    enum FileMode: String, CaseIterable, Identifiable {
        case symlink = "Symlink"
        case copy = "複製"
        var id: String { rawValue }
    }

    var isProcessing: Bool {
        phase != .idle && phase != .done && phase != .error
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
