import AppKit
import CoreText
import SwiftUI
import UniformTypeIdentifiers

struct FontPreviewView: View {
    @ObservedObject var viewModel: FontBrowserViewModel
    @State private var previewPreset: FontBrowserViewModel.PreviewPreset = .mixed
    @State private var previewSurface: FontPreviewSurface = .sample
    @State private var snippetStrategy: SnippetStrategy = .semantic
    @State private var codeLanguage: MiniTokenizer.Language = .swift
    @State private var codeSnippet: String = SnippetCatalog.snippet(language: .swift, strategy: .semantic)
    @State private var useSingleLinePreview = false
    @State private var useMonospacedDigits = false
    @State private var expandedLetterSpacing = false
    @State private var ligaturesEnabled = true
    @State private var zeroVariantEnabled = false
    @State private var enabledStylisticSetTags: Set<String> = []
    @State private var showScoreBreakdown = false
    @State private var activeWhyFactor: ProgrammingScoreFactor?
    @State private var compareFontID: String?
    @State private var showCopyToast = false
    @State private var activationMessage: String?
    @State private var activationConflictPath: String?
    @State private var fontBookMessage: String?
    @State private var fontBookPathHint: String?
    @State private var showInstallConfirm = false
    @State private var draftPreviewText = ""
    @State private var previewTextDebounceTask: Task<Void, Never>?
    @State private var variableAxes: [VariableFontAxis] = []
    @State private var variableAxisValues: [String: Double] = [:]
    @State private var customSnippetName = ""
    @State private var specimenExportMessage: String?

    private var factorLabels: FontPreviewFactorLabels {
        FontPreviewFactorLabels(tr: viewModel.tr)
    }
    private let featureBinder: OpenTypeFeatureBinding = OpenTypeFeatureBinder()
    private let configExporter = EditorConfigExporter()
    private var activationService: FontActivationServiceProtocol {
        viewModel.activationService
    }

    var body: some View {
        Group {
            if let selected = viewModel.selectedFont {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        FontPreviewHeaderSection(
                            viewModel: viewModel,
                            selected: selected,
                            activationService: activationService,
                            showCopyToast: $showCopyToast,
                            fontBookMessage: $fontBookMessage,
                            fontBookPathHint: $fontBookPathHint,
                            activationMessage: $activationMessage,
                            activationConflictPath: $activationConflictPath,
                            showInstallConfirm: $showInstallConfirm,
                            editorTitle: editorTitle,
                            editorCategoryTitle: editorCategoryTitle,
                            onCopyEditorConfig: copyEditorConfig,
                            onExportSpecimenPNG: exportSpecimenPNG,
                            onExportSpecimenPDF: exportSpecimenPDF,
                            onOpenInFontBook: openInFontBook,
                            onPerformActivation: performActivation
                        )
                        if let specimenExportMessage {
                            Text(specimenExportMessage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        previewSurfaceSection
                        if previewSurface == .sample {
                            quickSampleSection
                            previewTextField
                        } else {
                            codeLanguageSection
                        }
                        previewSizeSection
                        if !variableAxes.isEmpty {
                            VariableFontPreviewSection(
                                title: viewModel.tr(.variableFontAxes),
                                axes: variableAxes,
                                axisValues: $variableAxisValues
                            )
                        }
                        typographyOptionsSection
                        featureToggleSection(for: selected)
                        if selected.programming?.isMonospaced == true,
                           let score = selected.programmingScore {
                            FontPreviewProgrammingPanel(
                                viewModel: viewModel,
                                baseline: selected,
                                baselineScore: score,
                                factorLabels: factorLabels,
                                previewSurface: $previewSurface,
                                showScoreBreakdown: $showScoreBreakdown,
                                activeWhyFactor: $activeWhyFactor,
                                compareFontID: $compareFontID,
                                snippetStrategy: $snippetStrategy,
                                codeLanguage: $codeLanguage,
                                codeSnippet: codeSnippet,
                                highlightedCode: { text in
                                    CodeHighlightCache.attributedString(for: text, language: codeLanguage)
                                },
                                previewFont: previewFont,
                                codeLanguageTitle: codeLanguageTitle
                            )
                        }
                        if previewSurface == .sample {
                            previewBlocksSection(for: selected)
                        } else {
                            codePreviewSection(for: selected)
                        }
                        if !viewModel.hasRenderablePreviewFont() {
                            FontPreviewFallbackNotice(
                                message: viewModel.tr(.fallbackPreviewInfo),
                                isWarning: false
                            )
                        } else if viewModel.hasPartialGlyphFallback(for: draftPreviewText) {
                            FontPreviewFallbackNotice(
                                message: viewModel.tr(.fallbackPartialGlyphInfo),
                                isWarning: true
                            )
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                FontPreviewEmptyState(
                    title: viewModel.tr(.selectFontTitle),
                    hint: viewModel.tr(.selectFontHint),
                    tip: viewModel.tr(.selectFontTip)
                )
            }
        }
        .onChange(of: viewModel.selectedFont?.id, initial: true) { _, _ in
            guard let selected = viewModel.selectedFont else { return }
            loadFeaturePreferences(for: selected)
            reloadVariableAxes(for: selected)
        }
        .onChange(of: viewModel.previewSize) { _, _ in
            guard let selected = viewModel.selectedFont else { return }
            reloadVariableAxes(for: selected)
        }
        .onAppear {
            if draftPreviewText.isEmpty {
                draftPreviewText = viewModel.previewText
            }
        }
        .onChange(of: viewModel.previewText) { _, newValue in
            if draftPreviewText != newValue {
                draftPreviewText = newValue
            }
        }
        .onChange(of: draftPreviewText) { _, newValue in
            previewTextDebounceTask?.cancel()
            previewTextDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if viewModel.previewText != newValue {
                        viewModel.updatePreviewText(newValue)
                    }
                }
            }
        }
        .onDisappear {
            previewTextDebounceTask?.cancel()
            if viewModel.previewText != draftPreviewText {
                viewModel.updatePreviewText(draftPreviewText)
            }
        }
        .onChange(of: ligaturesEnabled) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .onChange(of: zeroVariantEnabled) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .onChange(of: enabledStylisticSetTags) { _, _ in
            persistFeaturePreferencesIfPossible()
        }
        .onChange(of: codeLanguage) { _, newLanguage in
            codeSnippet = SnippetCatalog.snippet(language: newLanguage, strategy: snippetStrategy)
        }
        .onChange(of: snippetStrategy) { _, newStrategy in
            codeSnippet = SnippetCatalog.snippet(language: codeLanguage, strategy: newStrategy)
        }
        .alert(viewModel.tr(.installConfirmTitle), isPresented: $showInstallConfirm) {
            Button(viewModel.tr(.installConfirmAction)) {
                if let selected = viewModel.selectedFont {
                    performActivation {
                        try activationService.installForUser(fontID: selected.postScriptName)
                    }
                }
            }
            Button(viewModel.tr(.cancel), role: .cancel) { }
        } message: {
            Text(viewModel.tr(.installConfirmMessage))
        }
    }

    private var quickSampleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.tr(.quickSample))
                .font(.caption)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                Picker(viewModel.tr(.quickSample), selection: $previewPreset) {
                    ForEach(FontBrowserViewModel.PreviewPreset.allCases) { preset in
                        Text(preset.title(language: viewModel.language)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Picker(viewModel.tr(.quickSample), selection: $previewPreset) {
                    ForEach(FontBrowserViewModel.PreviewPreset.allCases) { preset in
                        Text(preset.title(language: viewModel.language)).tag(preset)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            .onChange(of: previewPreset) { _, newPreset in
                viewModel.applyPreviewPreset(newPreset)
                draftPreviewText = newPreset.text
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewSurfaceSection: some View {
        FontPreviewSurfacePicker(
            selection: $previewSurface,
            title: viewModel.tr(.previewMode),
            sampleTitle: viewModel.tr(.previewModeSample),
            codeTitle: viewModel.tr(.previewModeCode)
        )
    }

    private var codeLanguageSection: some View {
        FontPreviewCodeControls(
            strategy: $snippetStrategy,
            language: $codeLanguage,
            code: $codeSnippet,
            customSnippetName: $customSnippetName,
            snippets: viewModel.customSnippets,
            tr: viewModel.tr,
            onAddSnippet: viewModel.addCustomSnippet,
            onRemoveSnippet: viewModel.removeCustomSnippet
        )
    }

    private var previewTextField: some View {
        TextField(viewModel.tr(.previewText), text: $draftPreviewText, axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(1...4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewSizeSection: some View {
        FontPreviewSizeControl(
            size: Binding(
                get: { viewModel.previewSize },
                set: { viewModel.previewSize = $0.rounded() }
            ),
            title: viewModel.tr(.previewSize),
            onChange: { viewModel.updatePreviewSize(viewModel.previewSize) }
        )
    }

    private var typographyOptionsSection: some View {
        FontPreviewDisplayOptions(
            singleLine: $useSingleLinePreview,
            monospacedDigits: $useMonospacedDigits,
            expandedLetterSpacing: $expandedLetterSpacing,
            showsWrapOption: previewSurface == .sample,
            wrapTitle: viewModel.tr(.previewWrapMode),
            digitsTitle: viewModel.tr(.previewMonospacedNumeralsStyle),
            spacingTitle: viewModel.tr(.previewExpandedLetterSpacing)
        )
    }

    @ViewBuilder
    private func featureToggleSection(for selected: FontItem) -> some View {
        if let profile = selected.programming, profile.isMonospaced {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tr(.featureSection))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(viewModel.tr(.featureLigatures), isOn: $ligaturesEnabled)
                    .toggleStyle(.switch)
                if profile.hasZeroVariant {
                    Toggle(viewModel.tr(.featureZeroVariant), isOn: $zeroVariantEnabled)
                        .toggleStyle(.switch)
                }
                if !profile.availableStylisticSets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(profile.availableStylisticSets, id: \.tag) { set in
                                Button(set.tag.uppercased()) {
                                    if enabledStylisticSetTags.contains(set.tag) {
                                        enabledStylisticSetTags.remove(set.tag)
                                    } else {
                                        enabledStylisticSetTags.insert(set.tag)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(enabledStylisticSetTags.contains(set.tag) ? .accentColor : .secondary)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func codeLanguageTitle(_ language: MiniTokenizer.Language) -> String {
        switch language {
        case .swift: return viewModel.tr(.languageSwift)
        case .typescript: return viewModel.tr(.languageTypeScript)
        case .javascript: return viewModel.tr(.languageJavaScript)
        case .python: return viewModel.tr(.languagePython)
        case .rust: return viewModel.tr(.languageRust)
        case .go: return viewModel.tr(.languageGo)
        case .java: return viewModel.tr(.languageJava)
        case .kotlin: return viewModel.tr(.languageKotlin)
        case .sql: return viewModel.tr(.languageSQL)
        case .json: return viewModel.tr(.languageJSON)
        case .shell: return viewModel.tr(.languageShell)
        case .css: return viewModel.tr(.languageCSS)
        }
    }

    @ViewBuilder
    private func previewBlocksSection(for selected: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            previewBlock(text: draftPreviewText, size: viewModel.previewSize, item: selected)
            previewBlock(text: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", size: max(14, viewModel.previewSize * 0.72), item: selected)
            previewBlock(text: "abcdefghijklmnopqrstuvwxyz 0123456789", size: max(12, viewModel.previewSize * 0.58), item: selected)
        }
    }

    @ViewBuilder
    private func previewBlock(text: String, size: Double, item: FontItem) -> some View {
        let prepared = FontPreviewTextRendering.prepare(text)
        if useSingleLinePreview {
            VStack(alignment: .leading, spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(prepared.renderText)
                        .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                        .tracking(expandedLetterSpacing ? 0.5 : 0)
                        .lineLimit(1)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.3))
                .cornerRadius(10)
                if prepared.didTruncate {
                    previewTruncationHint(originalCount: prepared.originalCount)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(prepared.renderText)
                    .font(previewFont(for: item, size: size, monospacedNumerals: useMonospacedDigits))
                    .tracking(expandedLetterSpacing ? 0.5 : 0)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.quaternary.opacity(0.3))
                    .cornerRadius(10)
                if prepared.didTruncate {
                    previewTruncationHint(originalCount: prepared.originalCount)
                }
            }
        }
    }

    @ViewBuilder
    private func codePreviewSection(for item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.tr(.codePreviewTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: true) {
                Text(CodeHighlightCache.attributedString(for: codeSnippet, language: codeLanguage))
                    .font(previewFont(for: item, size: max(12, viewModel.previewSize * 0.86), monospacedNumerals: true))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.quaternary.opacity(0.28))
            .cornerRadius(10)

            ambiguityLensSection(for: item)

            Text(viewModel.tr(.waterfallTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                let highlighted = CodeHighlightCache.attributedString(for: codeSnippet, language: codeLanguage)
                ForEach([11.0, 12.0, 13.0, 14.0, 16.0, 18.0], id: \.self) { size in
                    HStack(spacing: 8) {
                        Text("\(Int(size)) pt")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)
                        Text(highlighted)
                            .font(previewFont(for: item, size: size, monospacedNumerals: true))
                            .lineLimit(1)
                    }
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.2))
            .cornerRadius(10)

            glyphMatrixSection(for: item)
        }
    }

    @ViewBuilder
    private func ambiguityLensSection(for item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.tr(.ambiguityLensTitle))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Il1 O0 8B 5S 9gq rnm co ci {}()[] ,.;:")
                .font(previewFont(for: item, size: 32, monospacedNumerals: true))
                .lineLimit(1)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func glyphMatrixSection(for item: FontItem) -> some View {
        if let profile = item.programming,
           profile.hasPowerlineGlyphs || profile.hasNerdFontGlyphs {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.tr(.glyphMatrixTitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if profile.hasPowerlineGlyphs {
                    glyphGrid(
                        title: viewModel.tr(.powerlineGlyphsTitle),
                        entries: [("\u{E0A0}", "E0A0"), ("\u{E0A3}", "E0A3"), ("\u{E0B0}", "E0B0"), ("\u{E0B3}", "E0B3")],
                        item: item
                    )
                }
                if profile.hasNerdFontGlyphs {
                    glyphGrid(
                        title: viewModel.tr(.nerdFontGlyphsTitle),
                        entries: [("\u{E5FA}", "E5FA"), ("\u{E62B}", "E62B"), ("\u{F013}", "F013"), ("\u{F0C8}", "F0C8"), ("\u{F120}", "F120"), ("\u{F489}", "F489")],
                        item: item
                    )
                }
            }
        }
    }

    private func glyphGrid(title: String, entries: [(String, String)], item: FontItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                ForEach(entries, id: \.1) { entry in
                    VStack(spacing: 2) {
                        Text(entry.0)
                            .font(previewFont(for: item, size: 24, monospacedNumerals: true))
                        Text("U+\(entry.1)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.vertical, 6)
                    .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private func previewTruncationHint(originalCount: Int) -> some View {
        Label(
            String(
                format: viewModel.tr(.previewTruncatedInfo),
                FontPreviewTextRendering.previewTextLengthLimit,
                originalCount
            ),
            systemImage: "scissors"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func previewFont(for item: FontItem, size: Double, monospacedNumerals: Bool) -> Font {
        if !variableAxes.isEmpty {
            let axisValues = Dictionary(
                uniqueKeysWithValues: variableAxes.map { axis in
                    (axis.tag, variableAxisValues[axis.tag] ?? axis.defaultValue)
                }
            )
            if let nsFont = VariableFontInspector.font(
                postScriptName: item.postScriptName,
                size: size,
                axisValues: axisValues
            ) {
                return Font(nsFont)
            }
        }

        let options = OpenTypeFeatureOptions(
            ligaturesEnabled: ligaturesEnabled,
            zeroVariantEnabled: zeroVariantEnabled,
            stylisticSetTags: enabledStylisticSetTags
        )
        if let cached = PreviewFontCache.shared.font(
            postScriptName: item.postScriptName,
            size: size,
            options: options,
            binder: featureBinder
        ) {
            return cached
        }
        if monospacedNumerals && previewSurface == .sample {
            return .system(size: size, design: .monospaced)
        }
        return .system(size: size)
    }

    private func loadFeaturePreferences(for selected: FontItem) {
        guard let profile = selected.programming, profile.isMonospaced else {
            ligaturesEnabled = true
            zeroVariantEnabled = false
            enabledStylisticSetTags = []
            return
        }
        if let saved = viewModel.featurePreferences(forFontID: selected.id) {
            ligaturesEnabled = saved.ligaturesEnabled
            zeroVariantEnabled = profile.hasZeroVariant ? saved.zeroVariantEnabled : false
            let availableSets = Set(profile.availableStylisticSets.map { $0.tag.lowercased() })
            let savedSets = Set(saved.stylisticSetTags.map { $0.lowercased() })
            enabledStylisticSetTags = availableSets.intersection(savedSets)
        } else {
            ligaturesEnabled = profile.hasProgrammingLigatures
            zeroVariantEnabled = false
            enabledStylisticSetTags = []
        }
    }

    private func persistFeaturePreferencesIfPossible() {
        guard let selected = viewModel.selectedFont,
              let profile = selected.programming,
              profile.isMonospaced else { return }
        let normalizedSets = Set(profile.availableStylisticSets.map { $0.tag.lowercased() })
        let prefs = FontFeaturePreferences(
            ligaturesEnabled: ligaturesEnabled,
            zeroVariantEnabled: profile.hasZeroVariant ? zeroVariantEnabled : false,
            stylisticSetTags: enabledStylisticSetTags.intersection(normalizedSets)
        )
        viewModel.updateFeaturePreferences(prefs, forFontID: selected.id)
    }

    private func editorTitle(_ target: EditorTarget) -> String {
        viewModel.tr(target.l10nKey)
    }

    private func editorCategoryTitle(_ category: EditorTargetCategory) -> String {
        viewModel.tr(category.l10nKey)
    }

    private func reloadVariableAxes(for item: FontItem) {
        let axes = VariableFontInspector.axes(
            postScriptName: item.postScriptName,
            size: CGFloat(viewModel.previewSize)
        )
        variableAxes = axes
        variableAxisValues = Dictionary(
            uniqueKeysWithValues: axes.map { ($0.tag, $0.defaultValue) }
        )
    }

    private func exportSpecimenPNG() {
        saveSpecimen(format: .png)
    }

    private func exportSpecimenPDF() {
        saveSpecimen(format: .pdf)
    }

    private enum SpecimenExportFormat {
        case png
        case pdf
    }

    private func saveSpecimen(format: SpecimenExportFormat) {
        guard let selected = viewModel.selectedFont else { return }
        let nsFont = NSFont(name: selected.postScriptName, size: viewModel.previewSize)
            ?? NSFont.systemFont(ofSize: viewModel.previewSize)
        let previewText = draftPreviewText.isEmpty ? viewModel.previewText : draftPreviewText
        let data: Data?
        let fileExtension: String
        let contentType: UTType
        switch format {
        case .png:
            data = SpecimenExporter.pngData(
                familyName: selected.familyName(for: viewModel.language),
                displayName: selected.displayName(for: viewModel.language),
                postScriptName: selected.postScriptName,
                previewText: previewText,
                size: CGFloat(viewModel.previewSize),
                font: nsFont
            )
            fileExtension = "png"
            contentType = .png
        case .pdf:
            data = SpecimenExporter.pdfData(
                familyName: selected.familyName(for: viewModel.language),
                displayName: selected.displayName(for: viewModel.language),
                postScriptName: selected.postScriptName,
                previewText: previewText,
                size: CGFloat(viewModel.previewSize),
                font: nsFont
            )
            fileExtension = "pdf"
            contentType = .pdf
        }
        guard let data else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "\(selected.postScriptName)-specimen.\(fileExtension)"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try FileExportService.write(data, to: url)
                specimenExportMessage = viewModel.tr(.exportSpecimenSaved)
            } catch {
                specimenExportMessage = viewModel.tr(.exportFailed)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(.easeOut(duration: 0.15)) {
                    specimenExportMessage = nil
                }
            }
        }
    }

    private func copyEditorConfig(target: EditorTarget, postScriptName: String) {
        let snippet = configExporter.snippet(
            target: target,
            postScriptName: postScriptName,
            size: Int(viewModel.previewSize.rounded()),
            ligaturesEnabled: ligaturesEnabled
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            showCopyToast = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeOut(duration: 0.15)) {
                showCopyToast = false
            }
        }
    }

    private func openInFontBook(for item: FontItem) {
        fontBookMessage = nil
        fontBookPathHint = nil
        guard let url = resolveFontURL(postScriptName: item.postScriptName) else {
            fontBookMessage = viewModel.tr(.fontBookOpenFailed)
            return
        }
        if NSWorkspace.shared.open(url) {
            return
        }
        fontBookMessage = viewModel.tr(.fontBookOpenFailed)
        fontBookPathHint = url.path
    }

    private func resolveFontURL(postScriptName: String) -> URL? {
        FontURLResolver.url(forPostScriptName: postScriptName)
    }

    private func performActivation(_ operation: @escaping () throws -> Void) {
        Task { @MainActor in
            do {
                try operation()
                viewModel.refreshManagedFontState()
                activationMessage = viewModel.tr(.activationDone)
                activationConflictPath = nil
            } catch let FontActivationError.installConflict(destination) {
                activationMessage = viewModel.tr(.activationConflict)
                activationConflictPath = destination.path
            } catch {
                activationMessage = viewModel.tr(.activationFailed)
                activationConflictPath = nil
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            activationMessage = nil
            activationConflictPath = nil
        }
    }
}
