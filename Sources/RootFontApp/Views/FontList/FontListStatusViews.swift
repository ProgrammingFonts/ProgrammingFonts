import SwiftUI

struct FontImportBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
    }
}

struct FontScoreProgressBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

struct FontCatalogLoadingView: View {
    let progress: Double?
    let loadingText: String
    let enrichingText: String

    var body: some View {
        VStack(spacing: 10) {
            if let progress {
                ProgressView(value: progress) {
                    Text(progress < 0.5 ? loadingText : enrichingText)
                }
                .progressViewStyle(.linear)
            } else {
                ProgressView(loadingText)
            }
        }
        .controlSize(.small)
        .frame(maxWidth: 280)
    }
}
