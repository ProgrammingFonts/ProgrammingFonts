import SwiftUI

struct FontListBatchToolbar: View {
    let selectionCount: Int
    let tags: [String]
    let countText: String
    let favoriteTitle: String
    let activateTitle: String
    let tagTitle: String
    let clearTitle: String
    let onFavorite: () -> Void
    let onActivate: () -> Void
    let onApplyTag: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: countText, selectionCount))
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(favoriteTitle, action: onFavorite)
                .controlSize(.small)
            Button(activateTitle, action: onActivate)
                .controlSize(.small)
            if !tags.isEmpty {
                Menu(tagTitle) {
                    ForEach(tags, id: \.self) { tag in
                        Button(tag) { onApplyTag(tag) }
                    }
                }
                .controlSize(.small)
            }
            Spacer(minLength: 0)
            Button(clearTitle, action: onClear)
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }
}
