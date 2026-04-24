import Foundation

enum EditorTarget: String, CaseIterable, Identifiable, Sendable {
    case vscode
    case cursor
    case alacritty
    case kitty
    case warp
    case zed

    var id: Self { self }
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
        }
    }
}
