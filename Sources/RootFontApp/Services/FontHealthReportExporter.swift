import Foundation

struct FontHealthReportContext {
    let generatedAt: Date
    let brokenLabel: String
    let duplicateLabel: String
    let duplicateGroupLabel: String
    let sourceSystemLabel: String
    let sourceUserLabel: String
    let styleLabel: (FontItem) -> String
    let familyName: (FontItem) -> String
    let displayName: (FontItem) -> String
}

enum FontHealthReportExporter: Sendable {
    static func textReport(
        report: FontHealthReport,
        fontsByID: [String: FontItem],
        context: FontHealthReportContext
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: context.generatedAt)

        var lines: [String] = [
            "rootfont Font Health Report",
            "===========================",
            "Generated: \(timestamp)",
            "",
            "Summary",
            "-------",
            "- \(report.brokenFontIDs.count) \(context.brokenLabel.lowercased())",
            "- \(report.duplicateGroupCount) \(context.duplicateGroupLabel.lowercased())",
            "- \(report.affectedFontIDs.count) affected fonts",
            "",
        ]

        lines.append(context.brokenLabel)
        lines.append(String(repeating: "-", count: context.brokenLabel.count))
        if report.brokenFontIDs.isEmpty {
            lines.append("(none)")
        } else {
            for id in report.brokenFontIDs.sorted() {
                lines.append(fontLine(id: id, fontsByID: fontsByID, context: context))
            }
        }
        lines.append("")

        lines.append(context.duplicateLabel)
        lines.append(String(repeating: "-", count: context.duplicateLabel.count))
        if report.duplicateGroups.isEmpty {
            lines.append("(none)")
        } else {
            for (index, group) in report.duplicateGroups.enumerated() {
                let stylePart = group.styleSummary.isEmpty ? "" : " — \(group.styleSummary)"
                lines.append("")
                lines.append("Group \(index + 1): \(group.familyName)\(stylePart)")
                for fontID in group.fontIDs {
                    lines.append("  • \(fontLine(id: fontID, fontsByID: fontsByID, context: context, indented: true))")
                }
            }
        }

        lines.append("")
        lines.append("— rootfont")
        return lines.joined(separator: "\n")
    }

    private static func fontLine(
        id: String,
        fontsByID: [String: FontItem],
        context: FontHealthReportContext,
        indented: Bool = false
    ) -> String {
        guard let font = fontsByID[id] else {
            return indented ? id : "- \(id)"
        }
        let source = font.source == .system ? context.sourceSystemLabel : context.sourceUserLabel
        let prefix = indented ? "" : "- "
        return "\(prefix)\(context.familyName(font)) / \(context.displayName(font)) [\(font.postScriptName)] · \(context.styleLabel(font)) · \(source)"
    }
}
