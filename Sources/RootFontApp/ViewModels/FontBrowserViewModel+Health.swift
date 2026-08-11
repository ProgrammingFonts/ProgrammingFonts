import Foundation

@MainActor
extension FontBrowserViewModel {
    var fontHealthIssueCount: Int { fontHealthReport.issueCount }

    func fontItem(forID id: String) -> FontItem? { fontsByID[id] }

    func fontHealthIssues(for item: FontItem) -> Set<FontHealthIssueKind> {
        fontHealthReport.issueKinds(for: item.id)
    }

    func fontHealthIssueLabel(_ kind: FontHealthIssueKind) -> String {
        switch kind {
        case .broken: tr(.fontHealthBroken)
        case .duplicate: tr(.fontHealthDuplicates)
        }
    }

    func fontHealthSummaryText() -> String {
        String(
            format: tr(.fontHealthSummaryDetailed),
            fontHealthReport.brokenFontIDs.count,
            fontHealthReport.duplicateGroupCount,
            fontHealthReport.affectedFontIDs.count
        )
    }

    func fontHealthTextReport() -> String {
        FontHealthReportExporter.textReport(
            report: fontHealthReport,
            fontsByID: fontsByID,
            context: FontHealthReportContext(
                generatedAt: Date(),
                brokenLabel: tr(.fontHealthBroken),
                duplicateLabel: tr(.fontHealthDuplicates),
                duplicateGroupLabel: tr(.fontHealthDuplicateGroups),
                sourceSystemLabel: tr(.system),
                sourceUserLabel: tr(.user),
                styleLabel: styleLabel(for:),
                familyName: { $0.familyName(for: self.language) },
                displayName: { $0.displayName(for: self.language) }
            )
        )
    }

    func title(for option: SortOption) -> String {
        switch option {
        case .familyName: tr(.byFamilyName)
        case .displayName: tr(.byDisplayName)
        case .programmingFit: tr(.byProgrammingFit)
        }
    }
}
