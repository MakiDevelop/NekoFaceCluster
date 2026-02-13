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
                    Text("以圖搜人名")
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

            Spacer()

            if state.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在上傳圖片並開啟搜尋...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = state.searchError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "safari")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    Text("已在瀏覽器開啟 Yandex 反向搜圖")
                        .font(.headline)

                    Text("找到人名後，在下方輸入並套用")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Divider()

            // 名字輸入
            HStack(spacing: 8) {
                TextField("輸入人名...", text: $customName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit { applyCustomName() }

                Button("套用") { applyCustomName() }
                    .buttonStyle(.borderedProminent)
                    .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func applyCustomName() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state.applySearchName(trimmed, toCluster: clusterId)
        dismiss()
    }
}
