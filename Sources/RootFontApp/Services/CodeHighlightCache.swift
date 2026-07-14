import AppKit
import Foundation

/// Memoizes highlighted code attributed strings for preview + waterfall reuse.
enum CodeHighlightCache {
    private static let lock = NSLock()
    private static var cachedKey: String?
    private static var cachedValue: AttributedString?
    private static let tokenizer = MiniTokenizer()

    static func attributedString(
        for text: String,
        language: MiniTokenizer.Language
    ) -> AttributedString {
        let key = "\(language.rawValue)\u{1E}\(text)"
        lock.lock()
        if cachedKey == key, let cachedValue {
            lock.unlock()
            return cachedValue
        }
        lock.unlock()

        let rendered = render(text: text, language: language)

        lock.lock()
        cachedKey = key
        cachedValue = rendered
        lock.unlock()
        return rendered
    }

    static func clear() {
        lock.lock()
        cachedKey = nil
        cachedValue = nil
        lock.unlock()
    }

    private static func render(
        text: String,
        language: MiniTokenizer.Language
    ) -> AttributedString {
        let mutable = NSMutableAttributedString(string: text)
        let tokens = tokenizer.tokenize(text, language: language)
        for token in tokens {
            guard token.range.location != NSNotFound else { continue }
            let color: NSColor
            switch token.kind {
            case .keyword:
                color = .systemBlue
            case .type:
                color = .systemMint
            case .string:
                color = .systemOrange
            case .number:
                color = .systemPurple
            case .comment:
                color = .secondaryLabelColor
            case .punctuation, .operator:
                color = .systemPink
            case .identifier:
                color = .labelColor
            }
            mutable.addAttribute(.foregroundColor, value: color, range: token.range)
        }
        return (try? AttributedString(NSAttributedString(attributedString: mutable), including: \.appKit))
            ?? AttributedString(text)
    }
}
