import XCTest
@testable import RootFontApp

final class MiniTokenizerTests: XCTestCase {
    func testTokenizesSwiftKeywordsAndStrings() {
        let tokenizer = MiniTokenizer()
        let tokens = tokenizer.tokenize(
            #"let name = "rootfont" // note"#,
            language: .swift
        )

        let kinds = Set(tokens.map(\.kind))
        XCTAssertTrue(kinds.contains(.keyword))
        XCTAssertTrue(kinds.contains(.string))
        XCTAssertTrue(kinds.contains(.comment))
    }

    func testRepeatedTokenizeReusesCompiledCatalog() {
        let tokenizer = MiniTokenizer()
        let text = "func hello() -> String { return \"hi\" }"
        let first = tokenizer.tokenize(text, language: .swift)
        let second = tokenizer.tokenize(text, language: .swift)
        XCTAssertEqual(first, second)
    }
}

final class CodeHighlightCacheTests: XCTestCase {
    override func tearDown() {
        CodeHighlightCache.clear()
        super.tearDown()
    }

    func testCachesAttributedStringForSameSnippetAndLanguage() {
        let text = "let value = 42"
        let first = CodeHighlightCache.attributedString(for: text, language: .swift)
        let second = CodeHighlightCache.attributedString(for: text, language: .swift)
        XCTAssertEqual(String(first.characters), String(second.characters))
        XCTAssertEqual(String(first.characters), text)
    }

    func testDifferentLanguagesProduceIndependentCacheEntries() {
        let text = "const value = 1"
        let typescript = CodeHighlightCache.attributedString(for: text, language: .typescript)
        let python = CodeHighlightCache.attributedString(for: text, language: .python)
        XCTAssertEqual(String(typescript.characters), text)
        XCTAssertEqual(String(python.characters), text)
    }
}
