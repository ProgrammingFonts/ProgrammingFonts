import AppKit
import Foundation
import os

/// Memoizes highlighted code attributed strings for preview + waterfall reuse.
enum CodeHighlightCache {
    nonisolated(unsafe) private static var lock = os_unfair_lock_s()
    nonisolated(unsafe) private static var cachedKey: String?
    nonisolated(unsafe) private static var cachedValue: AttributedString?
    private static let tokenizer = MiniTokenizer()

    static func attributedString(
        for text: String,
        language: MiniTokenizer.Language
    ) -> AttributedString {
        let key = "\(language.rawValue)\u{1E}\(text)"
        os_unfair_lock_lock(&lock)
        if cachedKey == key, let cachedValue {
            os_unfair_lock_unlock(&lock)
            return cachedValue
        }
        os_unfair_lock_unlock(&lock)

        let rendered = render(text: text, language: language)

        os_unfair_lock_lock(&lock)
        cachedKey = key
        cachedValue = rendered
        os_unfair_lock_unlock(&lock)
        return rendered
    }

    static func clear() {
        os_unfair_lock_lock(&lock)
        cachedKey = nil
        cachedValue = nil
        os_unfair_lock_unlock(&lock)
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
