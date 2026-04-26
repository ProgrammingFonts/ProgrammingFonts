import XCTest
@testable import RootFontApp

final class SnippetCatalogTests: XCTestCase {
    func testAllLanguagesHaveSemanticAndNativeSnippets() {
        for language in MiniTokenizer.Language.allCases {
            let semantic = SnippetCatalog.snippet(language: language, strategy: .semantic)
            let native = SnippetCatalog.snippet(language: language, strategy: .native)
            XCTAssertFalse(semantic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "semantic empty for \(language.rawValue)")
            XCTAssertFalse(native.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "native empty for \(language.rawValue)")
        }
    }

    func testSemanticSnippetsContainCoreUserGreetingAnchor() {
        let languages: [MiniTokenizer.Language] = [.swift, .typescript, .javascript, .python, .rust, .go, .java, .kotlin]
        for language in languages {
            let snippet = SnippetCatalog.snippet(language: language, strategy: .semantic).lowercased()
            XCTAssertTrue(snippet.contains("user"), "missing user anchor for \(language.rawValue)")
            XCTAssertTrue(snippet.contains("hello") || snippet.contains("greet"), "missing greeting anchor for \(language.rawValue)")
        }
    }
}
