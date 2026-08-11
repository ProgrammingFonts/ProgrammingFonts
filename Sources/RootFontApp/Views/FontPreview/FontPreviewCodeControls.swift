import SwiftUI

struct FontPreviewCodeControls: View {
    @Binding var strategy: SnippetStrategy
    @Binding var language: MiniTokenizer.Language
    @Binding var code: String
    @Binding var customSnippetName: String
    let snippets: [CustomSnippet]
    let tr: (L10nKey) -> String
    let onAddSnippet: (String, String) -> Void
    let onRemoveSnippet: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(tr(.snippetStrategy), selection: $strategy) {
                Text(tr(.snippetStrategySemantic)).tag(SnippetStrategy.semantic)
                Text(tr(.snippetStrategyNative)).tag(SnippetStrategy.native)
            }
            .pickerStyle(.segmented)

            Picker(tr(.codeLanguage), selection: $language) {
                ForEach(MiniTokenizer.Language.allCases, id: \.self) { language in
                    Text(languageTitle(language)).tag(language)
                }
            }
            .pickerStyle(.menu)

            TextEditor(text: $code)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 120, maxHeight: 180)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary, lineWidth: 1))

            customSnippetControls
        }
    }

    private var customSnippetControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr(.customSnippets))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !snippets.isEmpty {
                Menu(tr(.customSnippets)) {
                    ForEach(snippets) { snippet in
                        Button(snippet.name) { code = snippet.text }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(tr(.customSnippetNamePlaceholder), text: $customSnippetName)
                    .textFieldStyle(.roundedBorder)
                Button(tr(.addCustomSnippet)) {
                    onAddSnippet(customSnippetName, code)
                    customSnippetName = ""
                }
                .disabled(customSnippetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(snippets) { snippet in
                HStack {
                    Text(snippet.name).font(.caption)
                    Spacer()
                    Button(tr(.deleteCustomSnippet), role: .destructive) {
                        onRemoveSnippet(snippet.id)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
        }
    }

    private func languageTitle(_ language: MiniTokenizer.Language) -> String {
        switch language {
        case .swift: tr(.languageSwift)
        case .typescript: tr(.languageTypeScript)
        case .javascript: tr(.languageJavaScript)
        case .python: tr(.languagePython)
        case .rust: tr(.languageRust)
        case .go: tr(.languageGo)
        case .java: tr(.languageJava)
        case .kotlin: tr(.languageKotlin)
        case .sql: tr(.languageSQL)
        case .json: tr(.languageJSON)
        case .shell: tr(.languageShell)
        case .css: tr(.languageCSS)
        }
    }
}
