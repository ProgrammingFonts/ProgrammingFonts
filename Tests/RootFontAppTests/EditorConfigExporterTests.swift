import XCTest
@testable import RootFontApp

final class EditorConfigExporterTests: XCTestCase {
    func testVSCodeSnippetContainsExpectedFields() {
        let exporter = EditorConfigExporter()
        let snippet = exporter.snippet(
            target: .vscode,
            postScriptName: "JetBrainsMono-Regular",
            size: 14,
            ligaturesEnabled: true
        )
        XCTAssertTrue(snippet.contains("\"editor.fontFamily\": \"JetBrainsMono-Regular\""))
        XCTAssertTrue(snippet.contains("\"editor.fontSize\": 14"))
        XCTAssertTrue(snippet.contains("\"editor.fontLigatures\": true"))
    }

    func testKittySnippetReflectsLigatureToggle() {
        let exporter = EditorConfigExporter()
        let snippet = exporter.snippet(
            target: .kitty,
            postScriptName: "FiraCode-Regular",
            size: 13,
            ligaturesEnabled: false
        )
        XCTAssertTrue(snippet.contains("font_family FiraCode-Regular"))
        XCTAssertTrue(snippet.contains("font_size 13"))
        XCTAssertTrue(snippet.contains("disable_ligatures always"))
    }
}
