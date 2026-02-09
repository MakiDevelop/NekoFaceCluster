import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("NekoFaceCluster")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select a folder of images to automatically\ngroup them by face identity.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "face.smiling", text: "Vision Framework face detection")
                FeatureRow(icon: "cpu", text: "M4 Max Neural Engine accelerated")
                FeatureRow(icon: "folder.badge.person.crop", text: "Auto-organize by person")
                FeatureRow(icon: "link", text: "Symlink mode preserves originals")
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
                .font(.body)
        }
    }
}
