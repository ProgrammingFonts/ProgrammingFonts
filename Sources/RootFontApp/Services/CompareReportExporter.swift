import AppKit
import Foundation

struct CompareReportInput {
    let baselineFamilyName: String
    let candidateFamilyName: String
    let baselinePostScriptName: String
    let candidatePostScriptName: String
    let baselineScore: ProgrammingScore
    let candidateScore: ProgrammingScore
    let baselineProfile: ProgrammingProfile?
    let candidateProfile: ProgrammingProfile?
    let codeSnippet: String
    let previewSize: CGFloat
    let factorTitle: (ProgrammingScoreFactor) -> String
    let bucketTitle: (CoverageBucket) -> String
}

enum CompareReportExporter: Sendable {
    static func textReport(input: CompareReportInput) -> String {
        let delta = input.candidateScore.total - input.baselineScore.total
        let signedDelta = delta >= 0 ? "+\(delta)" : "\(delta)"
        var lines: [String] = [
            "rootfont compare report",
            "========================",
            "",
            "Baseline: \(input.baselineFamilyName) (\(input.baselinePostScriptName))",
            "Candidate: \(input.candidateFamilyName) (\(input.candidatePostScriptName))",
            "",
            "Score: \(input.baselineScore.total) -> \(input.candidateScore.total) (\(signedDelta))",
            "",
            "Factor deltas:",
        ]

        let factorDeltas = ProgrammingScoreEngine.factorDeltas(
            baseline: input.baselineScore,
            candidate: input.candidateScore
        )
        for item in factorDeltas.prefix(12) {
            let signed = formatSigned(Int(round(item.delta)))
            lines.append("- \(input.factorTitle(item.factor)): \(signed)")
        }

        let coverage = coverageDiff(
            baseline: input.baselineProfile,
            candidate: input.candidateProfile
        )
        lines.append("")
        lines.append("Coverage:")
        lines.append("- Baseline only: \(coverageLabel(coverage.baselineOnly, input.bucketTitle))")
        lines.append("- Candidate only: \(coverageLabel(coverage.candidateOnly, input.bucketTitle))")
        lines.append("- Both: \(coverageLabel(coverage.both, input.bucketTitle))")

        lines.append("")
        lines.append("Snippet (\(Int(input.previewSize)) pt):")
        lines.append(input.codeSnippet)

        return lines.joined(separator: "\n")
    }

    static func pngData(input: CompareReportInput) -> Data? {
        let width: CGFloat = 980
        let height: CGFloat = 520
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width),
            pixelsHigh: Int(height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawComparePNG(input: input, in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    private static func drawComparePNG(input: CompareReportInput, in rect: NSRect) {

        NSColor.white.setFill()
        rect.fill()

        let titleFont = NSFont.systemFont(ofSize: 20, weight: .bold)
        let metaFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let bodyFontSize = max(12, input.previewSize * 0.72)
        let baselineFont = NSFont(name: input.baselinePostScriptName, size: bodyFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: bodyFontSize, weight: .regular)
        let candidateFont = NSFont(name: input.candidatePostScriptName, size: bodyFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: bodyFontSize, weight: .regular)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black,
        ]
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let baselineAttrs: [NSAttributedString.Key: Any] = [
            .font: baselineFont,
            .foregroundColor: NSColor.systemBlue,
        ]
        let candidateAttrs: [NSAttributedString.Key: Any] = [
            .font: candidateFont,
            .foregroundColor: NSColor.systemRed,
        ]

        let delta = input.candidateScore.total - input.baselineScore.total
        let signedDelta = delta >= 0 ? "+\(delta)" : "\(delta)"
        "Compare: \(input.baselineFamilyName) vs \(input.candidateFamilyName)".draw(
            at: NSPoint(x: 40, y: rect.height - 48),
            withAttributes: titleAttrs
        )
        "Score \(input.baselineScore.total) -> \(input.candidateScore.total) (\(signedDelta)) · rootfont".draw(
            at: NSPoint(x: 40, y: rect.height - 72),
            withAttributes: metaAttrs
        )

        let columnWidth = (rect.width - 120) / 2
        input.baselineFamilyName.draw(
            at: NSPoint(x: 40, y: rect.height - 104),
            withAttributes: metaAttrs
        )
        input.candidateFamilyName.draw(
            at: NSPoint(x: 40 + columnWidth + 40, y: rect.height - 104),
            withAttributes: metaAttrs
        )

        let snippetRect = NSRect(x: 40, y: 72, width: columnWidth, height: rect.height - 190)
        let candidateRect = NSRect(x: 40 + columnWidth + 40, y: 72, width: columnWidth, height: rect.height - 190)
        input.codeSnippet.draw(in: snippetRect, withAttributes: baselineAttrs)
        input.codeSnippet.draw(in: candidateRect, withAttributes: candidateAttrs)
    }

    private static func coverageDiff(
        baseline: ProgrammingProfile?,
        candidate: ProgrammingProfile?
    ) -> (baselineOnly: [CoverageBucket], candidateOnly: [CoverageBucket], both: [CoverageBucket]) {
        let left = baseline?.coverageBuckets ?? []
        let right = candidate?.coverageBuckets ?? []
        return (
            baselineOnly: left.subtracting(right).sorted { $0.rawValue < $1.rawValue },
            candidateOnly: right.subtracting(left).sorted { $0.rawValue < $1.rawValue },
            both: left.intersection(right).sorted { $0.rawValue < $1.rawValue }
        )
    }

    private static func coverageLabel(
        _ buckets: [CoverageBucket],
        _ title: (CoverageBucket) -> String
    ) -> String {
        buckets.isEmpty ? "-" : buckets.map(title).joined(separator: ", ")
    }

    private static func formatSigned(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
