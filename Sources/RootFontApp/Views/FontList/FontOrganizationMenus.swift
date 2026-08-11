import SwiftUI

func scoreChip(grade: ProgrammingGrade, language: AppLanguage) -> some View {
    Text(ProgrammingGradeUI.shortText(for: grade))
        .font(.caption2.weight(.bold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(ProgrammingGradeUI.color(for: grade).opacity(0.18), in: Capsule())
        .foregroundStyle(ProgrammingGradeUI.color(for: grade))
        .accessibilityLabel(L10n.tr(ProgrammingGradeUI.l10nKey(for: grade), language: language))
}

struct FontOrganizationMenus: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    let item: FontItem

    var body: some View {
        Menu(viewModel.tr(.addToCollection)) {
            if viewModel.manualCollections.isEmpty {
                Text(viewModel.tr(.noManualCollectionsYet))
            } else {
                ForEach(viewModel.manualCollections) { collection in
                    Button {
                        viewModel.toggleFont(item, inCollection: collection.id)
                    } label: {
                        Label(
                            collection.name,
                            systemImage: viewModel.isFont(item, inCollection: collection.id)
                                ? "checkmark"
                                : "folder"
                        )
                    }
                }
            }
        }

        if !viewModel.userTagNames.isEmpty {
            Menu(viewModel.tr(.fontTags)) {
                ForEach(viewModel.userTagNames, id: \.self) { tag in
                    Button {
                        viewModel.toggleTag(tag, on: item)
                    } label: {
                        Label(tag, systemImage: viewModel.hasTag(tag, on: item) ? "checkmark" : "tag")
                    }
                }
            }
        }
    }
}
