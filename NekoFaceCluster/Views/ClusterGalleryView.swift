import SwiftUI
import AppKit

struct ClusterGalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedCluster: PersonCluster?

    let columns = [GridItem(.adaptive(minimum: 200), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(state.clusters) { cluster in
                    PersonCard(cluster: cluster, isSelected: selectedCluster?.id == cluster.id)
                        .onTapGesture {
                            selectedCluster = cluster
                        }
                }

                // Uncategorized
                if !state.noisePaths.isEmpty {
                    UncategorizedCard(count: state.noisePaths.count)
                }
            }
            .padding()
        }
        .sheet(item: $selectedCluster) { cluster in
            PersonDetailView(cluster: cluster)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

struct PersonCard: View {
    let cluster: PersonCluster
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // 縮圖
            if let thumbPath = cluster.thumbnailPath,
               let nsImage = NSImage(contentsOfFile: thumbPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.quaternary)
                    .frame(width: 180, height: 180)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            Text(cluster.name)
                .font(.headline)
            Text("\(cluster.imagePaths.count) images")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct UncategorizedCard: View {
    let count: Int

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(width: 180, height: 180)
                .overlay {
                    Image(systemName: "questionmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }

            Text("Uncategorized")
                .font(.headline)
            Text("\(count) images")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

struct PersonDetailView: View {
    let cluster: PersonCluster
    @Environment(\.dismiss) private var dismiss

    let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        VStack {
            HStack {
                Text(cluster.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(cluster.imagePaths.count) images")
                    .foregroundStyle(.secondary)
                Button("Close") { dismiss() }
            }
            .padding()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(cluster.imagePaths, id: \.self) { path in
                        if let nsImage = NSImage(contentsOfFile: path) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
