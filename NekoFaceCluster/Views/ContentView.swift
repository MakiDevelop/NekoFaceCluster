import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            if state.clusters.isEmpty && !state.isProcessing {
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
        VStack(alignment: .leading, spacing: 16) {
            // 輸入目錄
            GroupBox("Input") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Select Folder...") { pickInputFolder() }
                        .disabled(state.isProcessing)
                    if let dir = state.inputDirectory {
                        Text(dir.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 輸出目錄
            GroupBox("Output") {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Select Output Folder...") { pickOutputFolder() }
                        .disabled(state.isProcessing)
                    if let dir = state.outputDirectory {
                        Text(dir.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 參數
            GroupBox("Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Sensitivity (eps): \(state.eps, specifier: "%.2f")")
                            .font(.caption)
                        Slider(value: $state.eps, in: 0.2...0.8, step: 0.05)
                    }

                    VStack(alignment: .leading) {
                        Text("Min Samples: \(state.minSamples)")
                            .font(.caption)
                        Stepper("\(state.minSamples)", value: $state.minSamples, in: 2...10)
                    }

                    Picker("File Mode", selection: $state.fileMode) {
                        ForEach(AppState.FileMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // 開始按鈕
            Button(action: startProcessing) {
                Label("Start Clustering", systemImage: "person.3.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(state.inputDirectory == nil || state.outputDirectory == nil || state.isProcessing)

            // 統計
            if state.phase == .done {
                GroupBox("Results") {
                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(label: "Persons found", value: "\(state.clusters.count)")
                        StatRow(label: "Total images", value: "\(state.totalImages)")
                        StatRow(label: "Total faces", value: "\(state.totalFaces)")
                        StatRow(label: "No face", value: "\(state.noFaceImages)")
                        StatRow(label: "Errors", value: "\(state.errorImages)")
                        StatRow(label: "Uncategorized", value: "\(state.noisePaths.count)")
                    }
                }
            }

            Spacer()

            Text(state.phase.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func pickInputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the folder containing images to sort"
        if panel.runModal() == .OK {
            state.inputDirectory = panel.url
        }
    }

    private func pickOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Select output folder for sorted images"
        if panel.runModal() == .OK {
            state.outputDirectory = panel.url
        }
    }

    private func startProcessing() {
        guard let inputDir = state.inputDirectory,
              let outputDir = state.outputDirectory else { return }

        state.reset()
        state.inputDirectory = inputDir
        state.outputDirectory = outputDir

        Task { @MainActor in
            do {
                // Phase 1: Scan
                state.phase = .scanning
                let imageURLs = ImageScanner.scan(directory: inputDir)
                state.totalImages = imageURLs.count

                guard !imageURLs.isEmpty else {
                    state.statusMessage = "No images found"
                    state.phase = .error
                    return
                }

                // Phase 2: Embed
                state.phase = .embedding
                let service = ClusteringService(
                    eps: Float(state.eps),
                    minSamples: state.minSamples
                )

                let result = try await service.process(imageURLs: imageURLs) { processed, total, file in
                    state.processedImages = processed
                    state.progress = Double(processed) / Double(total)
                    state.currentFile = file
                }

                // Phase 3: Update results
                state.phase = .clustering
                state.clusters = result.clusters
                state.noisePaths = result.noisePaths
                state.totalFaces = result.totalFaces
                state.noFaceImages = result.noFaceCount
                state.errorImages = result.errorCount

                // Phase 4: Organize files
                state.phase = .organizing
                let mode: FileOrganizer.Mode = state.fileMode == .symlink ? .symlink : .copy
                try FileOrganizer.organize(
                    clusters: result.clusters,
                    noisePaths: result.noisePaths,
                    to: outputDir,
                    mode: mode
                )

                state.phase = .done
                state.statusMessage = "完成！找到 \(result.clusters.count) 個人。"
            } catch {
                state.phase = .error
                state.statusMessage = error.localizedDescription
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}
