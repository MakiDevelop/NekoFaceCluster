import SwiftUI

struct SearchResultsView: View {
    let clusterId: Int
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var customName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("以圖搜尋")
                        .font(.title3.bold())
                    if let cluster = state.clusters.first(where: { $0.id == clusterId }) {
                        Text(cluster.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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

            // 內容
            if state.isSearching {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("搜尋中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if let error = state.searchError, state.searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if !state.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.searchResults) { result in
                            SearchResultRow(
                                result: result,
                                onUseName: { name in
                                    state.applySearchName(name, toCluster: clusterId)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // 手動輸入
            HStack(spacing: 8) {
                TextField("手動輸入名稱...", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { applyCustomName() }

                Button("套用") { applyCustomName() }
                    .buttonStyle(.borderedProminent)
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func applyCustomName() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state.applySearchName(trimmed, toCluster: clusterId)
        dismiss()
    }
}

// MARK: - 搜尋結果列

struct SearchResultRow: View {
    let result: SearchResult
    let onUseName: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                Text(result.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            VStack(spacing: 4) {
                Button("使用此名稱") {
                    onUseName(result.title)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    if let url = URL(string: result.url) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}
