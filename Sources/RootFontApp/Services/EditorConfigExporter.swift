import Foundation

enum EditorTargetCategory: String, CaseIterable, Identifiable, Sendable {
    case ide
    case terminal
    case aiTool

    var id: Self { self }

    var l10nKey: L10nKey {
        switch self {
        case .ide: return .editorCategoryIDE
        case .terminal: return .editorCategoryTerminal
        case .aiTool: return .editorCategoryAITool
        }
    }
}

enum EditorTarget: String, CaseIterable, Identifiable, Sendable {
    case vscode
    case cursor
    case zed
    case xcode
    case terminal
    case iterm2
    case alacritty
    case kitty
    case warp
    case wezterm
    case claudeCode
    case openCode
    case codex

    var id: Self { self }

    var category: EditorTargetCategory {
        switch self {
        case .vscode, .cursor, .zed, .xcode:
            return .ide
        case .terminal, .iterm2, .alacritty, .kitty, .warp, .wezterm:
            return .terminal
        case .claudeCode, .openCode, .codex:
            return .aiTool
        }
    }

    var l10nKey: L10nKey {
        switch self {
        case .vscode: return .editorVSCode
        case .cursor: return .editorCursor
        case .zed: return .editorZed
        case .xcode: return .editorXcode
        case .terminal: return .editorTerminal
        case .iterm2: return .editorITerm2
        case .alacritty: return .editorAlacritty
        case .kitty: return .editorKitty
        case .warp: return .editorWarp
        case .wezterm: return .editorWezTerm
        case .claudeCode: return .editorClaudeCode
        case .openCode: return .editorOpenCode
        case .codex: return .editorCodex
        }
    }

    static var grouped: [(EditorTargetCategory, [EditorTarget])] {
        EditorTargetCategory.allCases.map { category in
            (category, EditorTarget.allCases.filter { $0.category == category })
        }
    }
}

struct EditorConfigExporter: Sendable {
    func snippet(
        target: EditorTarget,
        postScriptName: String,
        size: Int,
        ligaturesEnabled: Bool
    ) -> String {
        switch target {
        case .vscode, .cursor:
            return """
            {
              "editor.fontFamily": "\(postScriptName)",
              "editor.fontSize": \(size),
              "editor.fontLigatures": \(ligaturesEnabled ? "true" : "false")
            }
            """
        case .zed:
            return """
            {
              "buffer_font_family": "\(postScriptName)",
              "buffer_font_size": \(size),
              "buffer_font_features": {
                "liga": \(ligaturesEnabled ? 1 : 0)
              }
            }
            """
        case .xcode:
            return """
            # Xcode > Settings > Themes > [Your Theme]
            # Source Editor: \(postScriptName) — \(size) pt
            # Console: use the same font for consistent output
            """
        case .terminal:
            return """
            # Terminal.app > Settings > Profiles > [Profile] > Font…
            # PostScript name: \(postScriptName)
            # Size: \(size) pt
            """
        case .iterm2:
            return """
            {
              "Profiles": [
                {
                  "Name": "rootfont",
                  "Normal Font": "\(postScriptName) \(size)"
                }
              ]
            }
            """
        case .alacritty:
            return """
            [font]
            size = \(size)
            normal = { family = "\(postScriptName)", style = "Regular" }
            """
        case .kitty:
            return """
            font_family \(postScriptName)
            font_size \(size)
            disable_ligatures \(ligaturesEnabled ? "never" : "always")
            """
        case .warp:
            return """
            [font]
            family = "\(postScriptName)"
            size = \(size)
            ligatures = \(ligaturesEnabled ? "true" : "false")
            """
        case .wezterm:
            return """
            -- ~/.wezterm.lua
            config.font = wezterm.font('\(postScriptName)')
            config.font_size = \(size)
            config.harfbuzz_features = { '\(ligaturesEnabled ? "liga=1" : "liga=0")' }
            """
        case .claudeCode:
            return """
            {
              "terminal": {
                "fontFamily": "\(postScriptName)",
                "fontSize": \(size)
              }
            }
            """
        case .openCode:
            return """
            {
              "font": "\(postScriptName)",
              "fontSize": \(size)
            }
            """
        case .codex:
            return """
            # ~/.codex/config.toml
            font_family = "\(postScriptName)"
            font_size = \(size)
            """
        }
    }
}
