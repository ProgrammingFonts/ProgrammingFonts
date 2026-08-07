import SwiftUI

struct FontPreviewEmptyState: View {
    let title: String
    let hint: String
    let tip: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "textformat.alt")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(tip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FontPreviewFallbackNotice: View {
    let message: String
    let isWarning: Bool

    var body: some View {
        Label(
            message,
            systemImage: isWarning ? "exclamationmark.circle" : "info.circle"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
