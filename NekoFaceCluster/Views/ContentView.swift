import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            if state.clusters.isEmpty && !state.isProcessing && !state.isReviewing {
                WelcomeView()
            } else if state.isProcessing {
                ProcessingView()
            } else {
                ClusterGalleryView()
            }
        }
        .navigationTitle("NekoFaceCluster")
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 資料夾選擇
                FolderSection(
                    title: "輸入資料夾",
                    icon: "folder.fill",
                    color: .blue,
                    url: state.inputDirectory,
                    disabled: state.isProcessing || state.isReviewing,
                    action: pickInputFolder
                )

                FolderSection(
                    title: "輸出資料夾",
                    icon: "folder.badge.plus",
                    color: .green,
                    url: state.outputDirectory,
                    disabled: state.isProcessing || state.isReviewing,
                    action: pickOutputFolder
                )

                Divider()

                // 參數
                VStack(alignment: .leading, spacing: 14) {
                    Label("設定", systemImage: "slider.horizontal.3")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("配對門檻 (eps: \(state.eps, specifier: "%.2f"))")
                            .font(.caption)
                        Slider(value: $state.eps, in: 0.2...0.8, step: 0.05)
                            .disabled(state.isReviewing)
                        HStack {
                            Text("嚴格").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("寬鬆").font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("最少樣本數")
                            .font(.caption)
                        Spacer()
                        Stepper("\(state.minSamples)", value: $state.minSamples, in: 1...10)
                            .fixedSize()
                            .disabled(state.isReviewing)
                    }

                    Picker(selection: $state.fileMode) {
                        ForEach(AppState.FileMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    } label: {
                        Text("輸出模式")
                            .font(.caption)
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("SearXNG", systemImage: "magnifyingglass")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        TextField("URL", text: $state.searxngBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        Text("反向圖搜辨識人名")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // 按鈕區
                if state.isReviewing {
                    // 審核模式：確認整理 + 重新分群
                    VStack(spacing: 8) {
                        Button(action: confirmOrganize) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("確認整理")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)

                        Button(action: { state.reset() }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("重新開始")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    // 審核中的統計
                    ResultsSection()

                } else if state.phase == .done {
                    // 完成
                    Label(state.statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                    Button(action: { state.reset() }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重新開始")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                } else {
                    // 開始按鈕
                    Button(action: startProcessing) {
                        HStack {
                            Image(systemName: state.isProcessing ? "gearshape.2.fill" : "play.fill")
                                .symbolEffect(.pulse, isActive: state.isProcessing)
                            Text(state.isProcessing ? "處理中..." : "開始分群")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(state.inputDirectory == nil || state.outputDirectory == nil || state.isProcessing)
                }

                if state.isProcessing {
                    Button(action: cancelProcessing) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("取消處理")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(.red)
                }

                // 錯誤訊息
                if state.phase == .error, !state.statusMessage.isEmpty {
                    Label(state.statusMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
    }

    private func pickInputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "選擇包含圖片的資料夾"
        if panel.runModal() == .OK {
            state.inputDirectory = panel.url
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "選擇分群結果的輸出位置"
        if panel.runModal() == .OK {
            state.outputDirectory = panel.url
        }
    }

    /// 分群完停在 reviewing，不搬檔案
    private func startProcessing() {
        guard let inputDir = state.inputDirectory,
              let outputDir = state.outputDirectory else { return }

        state.reset()
        state.inputDirectory = inputDir
        state.outputDirectory = outputDir

        let task = Task { @MainActor in
            do {
                // Check early
                try Task.checkCancellation()

                state.phase = .scanning
                let imageURLs = ImageScanner.scan(directory: inputDir)
                state.totalImages = imageURLs.count

                guard !imageURLs.isEmpty else {
                    state.statusMessage = "資料夾中沒有找到圖片"
                    state.phase = .error
                    return
                }

                state.phase = .embedding
                let service = ClusteringService(
                    eps: Float(state.eps),
                    minSamples: state.minSamples
                )

                let result = try await service.process(imageURLs: imageURLs) { info in
                    // The progress closure is called from within possibly cancelled task; guard inside service too
                    state.processedImages = info.processed
                    state.progress = Double(info.processed) / Double(info.total)
                    state.currentFile = info.file
                    state.totalFaces = info.totalFaces
                    state.noFaceImages = info.noFaceCount
                    state.errorImages = info.errorCount
                }

                // If cancelled during await, the result may be partial but we still check
                try Task.checkCancellation()

                state.clusters = result.clusters
                state.noisePaths = result.noisePaths
                state.totalFaces = result.totalFaces
                state.noFaceImages = result.noFaceCount
                state.errorImages = result.errorCount

                // 停在審核階段，讓用戶命名、移除後再整理
                state.phase = .reviewing
                state.statusMessage = "分群完成，請審核後點「確認整理」"

            } catch is CancellationError {
                state.phase = .error
                state.statusMessage = "處理已取消"
            } catch {
                state.phase = .error
                state.statusMessage = error.localizedDescription
            }
            state.setProcessingTask(nil)
        }
        state.setProcessingTask(task)
    }

    private func cancelProcessing() {
        state.cancelProcessing()
    }

    /// 用戶確認後才搬檔案
    private func confirmOrganize() {
        guard let outputDir = state.outputDirectory else { return }

        Task { @MainActor in
            do {
                state.phase = .organizing
                let mode: FileOrganizer.Mode
                switch state.fileMode {
                case .move: mode = .move
                case .copy: mode = .copy
                case .symlink: mode = .symlink
                }
                try FileOrganizer.organize(
                    clusters: state.clusters,
                    noisePaths: state.noisePaths,
                    to: outputDir,
                    mode: mode
                )

                // 更新路徑指向輸出位置，避免移動後縮圖失效
                for i in state.clusters.indices {
                    let personDir = outputDir.appendingPathComponent(state.clusters[i].name)
                    state.clusters[i].imagePaths = state.clusters[i].imagePaths.map { path in
                        personDir.appendingPathComponent(
                            URL(fileURLWithPath: path).lastPathComponent
                        ).path
                    }
                }

                state.phase = .done
                state.statusMessage = "整理完成！\(state.clusters.count) 個人物已輸出。"
            } catch {
                state.phase = .error
                state.statusMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Sidebar Components

struct FolderSection: View {
    let title: String
    let icon: String
    let color: Color
    let url: URL?
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack {
                    if let url {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(color)
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(color)
                        Text("選擇資料夾...")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
        }
    }
}

struct ResultsSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("分群統計", systemImage: "chart.bar.fill")
                .font(.caption.bold())
                .foregroundStyle(.blue)

            VStack(spacing: 4) {
                StatRow(label: "人物數", value: "\(state.clusters.count)", color: .blue)
                StatRow(label: "圖片總數", value: "\(state.totalImages)", color: .primary)
                StatRow(label: "偵測人臉", value: "\(state.totalFaces)", color: .purple)
                StatRow(label: "無人臉", value: "\(state.noFaceImages)", color: .orange)
                StatRow(label: "錯誤", value: "\(state.errorImages)", color: .red)
                StatRow(label: "未分類", value: "\(state.noisePaths.count)", color: .secondary)
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(color)
        }
    }
}
