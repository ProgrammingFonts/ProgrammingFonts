import AppKit
import Foundation

enum FontHealthIssueKind: String, Sendable, CaseIterable {
    case broken
    case duplicate
}

struct FontHealthDuplicateGroup: Identifiable, Hashable, Sendable {
    let id: String
    let familyName: String
    let styleSummary: String
    let fontIDs: [String]
}

struct FontHealthReport: Sendable, Equatable {
    let brokenFontIDs: Set<String>
    let duplicateFontIDs: Set<String>
    let duplicateGroups: [FontHealthDuplicateGroup]

    var affectedFontIDs: Set<String> {
        brokenFontIDs.union(duplicateFontIDs)
    }

    var duplicateGroupCount: Int {
        duplicateGroups.count
    }

    var issueCount: Int {
        brokenFontIDs.count + duplicateGroupCount
    }

    func issueKinds(for fontID: String) -> Set<FontHealthIssueKind> {
        var kinds = Set<FontHealthIssueKind>()
        if brokenFontIDs.contains(fontID) {
            kinds.insert(.broken)
        }
        if duplicateFontIDs.contains(fontID) {
            kinds.insert(.duplicate)
        }
        return kinds
    }

    static let empty = FontHealthReport(
        brokenFontIDs: [],
        duplicateFontIDs: [],
        duplicateGroups: []
    )
}

enum FontHealthAnalyzer: Sendable {
    static func analyze(
        fonts: [FontItem],
        weightResolver: FontWeightTierResolving = FontWeightTierResolver()
    ) -> FontHealthReport {
        var broken = Set<String>()
        for font in fonts where NSFont(name: font.postScriptName, size: 12) == nil {
            broken.insert(font.id)
        }

        var groups: [String: [FontItem]] = [:]
        for font in fonts {
            let weightTier = font.weightTier
                ?? weightResolver.resolveWeightTier(postScriptName: font.postScriptName)
            let styleKey = font.styleTags
                .map(\.rawValue)
                .sorted()
                .joined(separator: ", ")
            let familyKey = font.familyName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let key = "\(familyKey)|\(weightTier.rawValue)|\(styleKey)"
            groups[key, default: []].append(font)
        }

        var duplicateIDs = Set<String>()
        var duplicateGroups: [FontHealthDuplicateGroup] = []
        for (key, group) in groups where group.count > 1 {
            let familyName = group.first?.familyName ?? "Unknown"
            let weightTier = group.first?.weightTier
                ?? group.first.map { weightResolver.resolveWeightTier(postScriptName: $0.postScriptName) }
                ?? .regular
            let styleSummary = ([weightTier.rawValue] + (group.first?.styleTags.map(\.rawValue).sorted() ?? []))
                .joined(separator: ", ")
            let sortedIDs = group.map(\.id).sorted()
            for font in group {
                duplicateIDs.insert(font.id)
            }
            duplicateGroups.append(
                FontHealthDuplicateGroup(
                    id: key,
                    familyName: familyName,
                    styleSummary: styleSummary,
                    fontIDs: sortedIDs
                )
            )
        }

        duplicateGroups.sort {
            $0.familyName.localizedCaseInsensitiveCompare($1.familyName) == .orderedAscending
        }

        return FontHealthReport(
            brokenFontIDs: broken,
            duplicateFontIDs: duplicateIDs,
            duplicateGroups: duplicateGroups
        )
    }
}
