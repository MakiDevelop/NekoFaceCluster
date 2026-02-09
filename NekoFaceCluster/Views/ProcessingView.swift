import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 圓形進度
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: state.progress)
                    .stroke(.blue.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: state.progress)

                VStack(spacing: 4) {
                    Text("\(Int(state.progress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("\(state.processedImages)/\(state.totalImages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // 階段
            VStack(spacing: 8) {
                Text(state.phase.rawValue)
                    .font(.headline)

                if !state.currentFile.isEmpty {
                    Text(state.currentFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }

            // 即時統計
            HStack(spacing: 24) {
                StatBadge(value: state.totalFaces, label: "人臉", icon: "face.smiling", color: .blue)
                StatBadge(value: state.noFaceImages, label: "無人臉", icon: "face.dashed", color: .orange)
                StatBadge(value: state.errorImages, label: "錯誤", icon: "exclamationmark.triangle", color: .red)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatBadge: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text("\(value)")
                .font(.title2.monospacedDigit().bold())
                .contentTransition(.numericText())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 80)
        .padding(.vertical, 12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
