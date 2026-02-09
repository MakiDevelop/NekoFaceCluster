import SwiftUI

struct WelcomeView: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.05 : 1.0)

                Image(systemName: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.gradient)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("NekoFaceCluster")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("圖片人臉自動分群工具")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "face.smiling", color: .blue, text: "Vision Framework 人臉偵測")
                FeatureRow(icon: "cpu", color: .purple, text: "Apple Silicon Neural Engine 加速")
                FeatureRow(icon: "folder.badge.person.crop", color: .orange, text: "依人物自動分類整理")
                FeatureRow(icon: "link", color: .green, text: "Symlink 模式不佔額外空間")
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("從左側選擇資料夾開始")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            Text(text)
                .font(.body)
        }
    }
}
