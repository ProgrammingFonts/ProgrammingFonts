import AppKit
import SwiftUI

struct FontHealthReportView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var copiedToast = false

    private var report: FontHealthReport {
        viewModel.fontHealthReport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerSection
            summarySection

            if report.brokenFontIDs.isEmpty && report.duplicateGroups.isEmpty {
                healthyBanner
            } else {
                if !report.brokenFontIDs.isEmpty {
                    brokenSection
                }
                if !report.duplicateGroups.isEmpty {
                    duplicateSection
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.title3)
                .foregroundStyle(report.affectedFontIDs.isEmpty ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.tr(.fontHealthReportTitle))
                    .font(.headline)
                Text(viewModel.fontHealthSummaryText())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(viewModel.tr(.fontHealthExportReport)) {
                copyReport()
            }
            .controlSize(.small)
            if copiedToast {
                Text(viewModel.tr(.fontHealthReportCopied))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
    }

    private var summarySection: some View {
        HStack(spacing: 10) {
            summaryChip(
                title: viewModel.tr(.fontHealthBroken),
                value: "\(report.brokenFontIDs.count)",
                tint: .red
            )
            summaryChip(
                title: viewModel.tr(.fontHealthDuplicateGroups),
                value: "\(report.duplicateGroupCount)",
                tint: .orange
            )
            summaryChip(
                title: viewModel.tr(.fontHealthAffectedFonts),
                value: "\(report.affectedFontIDs.count)",
                tint: .blue
            )
        }
    }

    private var healthyBanner: some View {
        Label(viewModel.tr(.fontHealthNoIssues), systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.green)
            .padding(.vertical, 4)
    }

    private var brokenSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(viewModel.tr(.fontHealthBrokenSection), systemImage: "xmark.octagon.fill", tint: .red)
            Text(viewModel.tr(.fontHealthBrokenHint))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(sortedBrokenFonts) { item in
                issueRow(item: item, kinds: [.broken])
            }
        }
    }

    private var duplicateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(viewModel.tr(.fontHealthDuplicatesSection), systemImage: "doc.on.doc.fill", tint: .orange)
            Text(viewModel.tr(.fontHealthDuplicateHint))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(report.duplicateGroups) { group in
                duplicateGroupCard(group)
            }
        }
    }

    private var sortedBrokenFonts: [FontItem] {
        report.brokenFontIDs
            .compactMap { viewModel.fontItem(forID: $0) }
            .sorted {
                $0.familyName(for: viewModel.language)
                    .localizedCaseInsensitiveCompare($1.familyName(for: viewModel.language))
                    == .orderedAscending
            }
    }

    @ViewBuilder
    private func duplicateGroupCard(_ group: FontHealthDuplicateGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(
                String(
                    format: viewModel.tr(.fontHealthDuplicateGroupTitle),
                    group.familyName,
                    group.styleSummary.isEmpty ? viewModel.tr(.fontHealthDefaultStyle) : group.styleSummary
                )
            )
            .font(.subheadline.weight(.semibold))
            ForEach(group.fontIDs, id: \.self) { fontID in
                if let item = viewModel.fontItem(forID: fontID) {
                    issueRow(item: item, kinds: [.duplicate])
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func issueRow(item: FontItem, kinds: Set<FontHealthIssueKind>) -> some View {
        Button {
            viewModel.handleFontTap(item, commandKey: false)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.familyName(for: viewModel.language))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(item.displayName(for: viewModel.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.postScriptName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    ForEach(Array(kinds).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { kind in
                        issueBadge(kind)
                    }
                    Text(viewModel.sourceLabel(for: item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func issueBadge(_ kind: FontHealthIssueKind) -> some View {
        Text(viewModel.fontHealthIssueLabel(kind))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(issueBadgeColor(kind).opacity(0.15), in: Capsule())
            .foregroundStyle(issueBadgeColor(kind))
    }

    private func issueBadgeColor(_ kind: FontHealthIssueKind) -> Color {
        switch kind {
        case .broken: return .red
        case .duplicate: return .orange
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private func summaryChip(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyReport() {
        let text = viewModel.fontHealthTextReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            copiedToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                copiedToast = false
            }
        }
    }
}
