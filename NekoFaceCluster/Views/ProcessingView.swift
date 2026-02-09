import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: state.progress) {
                Text(state.phase.rawValue)
                    .font(.headline)
            } currentValueLabel: {
                Text("\(state.processedImages) / \(state.totalImages)")
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 400)

            if !state.currentFile.isEmpty {
                Text(state.currentFile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 40) {
                VStack {
                    Text("\(state.totalFaces)")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.bold)
                    Text("Faces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(state.noFaceImages)")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.bold)
                    Text("No Face")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack {
                    Text("\(state.errorImages)")
                        .font(.title2.monospacedDigit())
                        .fontWeight(.bold)
                    Text("Errors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
