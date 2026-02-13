import SwiftUI
import AppKit

struct ClusterGalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedCluster: PersonCluster?
    @State private var hoveredId: Int?
    @State private var editingId: Int?
    @State private var editingName: String = ""

    let columns = [GridItem(.adaptive(minimum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            // 頂部摘要
            HStack(spacing: 16) {
                SummaryPill(icon: "person.3.fill", value: "\(state.clusters.count)", label: "人物", color: .blue)
                SummaryPill(icon: "photo.stack", value: "\(state.totalImages)", label: "圖片", color: .purple)
                if !state.noisePaths.isEmpty {
                    SummaryPill(icon: "questionmark.circle", value: "\(state.noisePaths.count)", label: "未分類", color: .orange)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(state.clusters) { cluster in
                    PersonCard(
                        cluster: cluster,
                        isHovered: hoveredId == cluster.id,
                        isEditing: editingId == cluster.id,
                        editingName: editingId == cluster.id ? $editingName : .constant(""),
                        isReviewing: state.isReviewing,
                        onTap: { selectedCluster = cluster },
                        onDoubleTap: { startEditing(cluster) },
                        onCommitName: { commitName(for: cluster.id) },
                        onRemoveCluster: { state.removeCluster(id: cluster.id) },
                        onSearch: { state.startSearch(for: cluster.id) }
                    )
                    .zIndex(hoveredId == cluster.id ? 1 : 0)
                    .onHover { hovering in hoveredId = hovering ? cluster.id : nil }
                }

                if !state.noisePaths.isEmpty {
                    UncategorizedCard(
                        count: state.noisePaths.count,
                        isReviewing: state.isReviewing,
                        onClear: { state.noisePaths.removeAll() }
                    )
                }
            }
            .padding()
        }
        .sheet(item: $selectedCluster) { (initial: PersonCluster) in
            PersonDetailView(clusterId: initial.id)
                .environmentObject(state)
                .frame(minWidth: 700, minHeight: 500)
        }
        .sheet(isPresented: Binding(
            get: { state.searchingClusterId != nil },
            set: { if !$0 { state.dismissSearch() } }
        )) {
            if let clusterId = state.searchingClusterId {
                SearchResultsView(clusterId: clusterId)
                    .environmentObject(state)
            }
        }
    }

    private func startEditing(_ cluster: PersonCluster) {
        editingName = cluster.name
        editingId = cluster.id
    }

    private func commitName(for id: Int) {
        let trimmed = editingName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            state.renameCluster(id: id, to: trimmed)
        }
        editingId = nil
    }
}

// MARK: - Summary

struct SummaryPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value).fontWeight(.bold)
            Text(label).foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.08), in: Capsule())
    }
}

// MARK: - Person Card

struct PersonCard: View {
    let cluster: PersonCluster
    let isHovered: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let isReviewing: Bool
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onCommitName: () -> Void
    let onRemoveCluster: () -> Void
    let onSearch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    if let thumbPath = cluster.thumbnailPath,
                       let nsImage = NSImage(contentsOfFile: thumbPath) {
                        Color.clear
                            .frame(height: 200)
                            .overlay {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.tertiary)
                            }
                    }

                    Text("\(cluster.imagePaths.count)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }

                // 審核模式：圖片右上角常駐顯示移除按鈕
                if isReviewing {
                    Button(action: onRemoveCluster) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
            .onTapGesture { onTap() }

            HStack {
                if isEditing {
                    TextField("名稱", text: $editingName, onCommit: onCommitName)
                        .textFieldStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .onExitCommand { onCommitName() }
                } else {
                    Text(cluster.name)
                        .font(.subheadline.weight(.semibold))
                        .onTapGesture(count: 2) { onDoubleTap() }
                    Spacer()
                    if isReviewing {
                        Image(systemName: "magnifyingglass")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .onTapGesture { onSearch() }
                            .help("以圖搜人")
                    }
                    Image(systemName: "pencil")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .onTapGesture { onDoubleTap() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.06), radius: isHovered ? 12 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Uncategorized Card

struct UncategorizedCard: View {
    let count: Int
    let isReviewing: Bool
    let onClear: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 200)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                            Text("\(count) 張")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                if isReviewing {
                    Button(action: onClear) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }

            HStack {
                Text("未分類")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.06), radius: isHovered ? 12 : 4, y: isHovered ? 4 : 2)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Person Detail

struct PersonDetailView: View {
    let clusterId: Int
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editedName: String = ""
    @State private var isEditingName = false
    @State private var zoomedImagePath: String?
    @State private var hoveredPath: String?

    let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    private var cluster: PersonCluster? {
        state.clusters.first { $0.id == clusterId }
    }

    var body: some View {
        ZStack {
            if let cluster {
                // 主內容
                VStack(spacing: 0) {
                    // 標題列
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            if isEditingName {
                                TextField("名稱", text: $editedName, onCommit: {
                                    let trimmed = editedName.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty { state.renameCluster(id: clusterId, to: trimmed) }
                                    isEditingName = false
                                })
                                .textFieldStyle(.plain)
                                .font(.title2.bold())
                            } else {
                                HStack(spacing: 8) {
                                    Text(cluster.name)
                                        .font(.title2.bold())
                                    Button { startEditing() } label: {
                                        Image(systemName: "pencil.circle")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    if state.isReviewing {
                                        Button {
                                            dismiss()
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                state.startSearch(for: clusterId)
                                            }
                                        } label: {
                                            Image(systemName: "magnifyingglass.circle")
                                                .foregroundStyle(.blue)
                                        }
                                        .buttonStyle(.plain)
                                        .help("以圖搜人")
                                    }
                                }
                            }
                            Text("\(cluster.imagePaths.count) 張圖片")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Text("雙擊放大 · hover 顯示移除")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(.bar)

                    Divider()

                    // 圖片網格
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(cluster.imagePaths, id: \.self) { path in
                                ImageCell(
                                    path: path,
                                    isHovered: hoveredPath == path,
                                    onDoubleClick: { zoomedImagePath = path },
                                    onRemove: { state.removeImage(path, fromCluster: clusterId) }
                                )
                                .onHover { hovering in hoveredPath = hovering ? path : nil }
                            }
                        }
                        .padding()
                    }
                }
            }

            // 全螢幕放大 overlay
            if let zoomedPath = zoomedImagePath,
               let nsImage = NSImage(contentsOfFile: zoomedPath) {
                ZoomOverlay(nsImage: nsImage) {
                    zoomedImagePath = nil
                }
            }
        }
        .onAppear { editedName = cluster?.name ?? "" }
        .onChange(of: cluster == nil) { isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private func startEditing() {
        editedName = cluster?.name ?? ""
        isEditingName = true
    }
}

// MARK: - Image Cell（hover 移除 + 雙擊放大）

struct ImageCell: View {
    let path: String
    let isHovered: Bool
    let onDoubleClick: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture(count: 2) { onDoubleClick() }
            }

            // Hover 時顯示移除按鈕
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Zoom Overlay

struct ZoomOverlay: View {
    let nsImage: NSImage
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(40)
                .onTapGesture { onDismiss() }

            // 右上角關閉
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .transition(.opacity)
    }
}
