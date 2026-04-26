import Foundation

struct MiniToken: Sendable, Hashable {
    enum Kind: Sendable {
        case keyword
        case type
        case string
        case number
        case comment
        case punctuation
        case `operator`
        case identifier
    }

    let range: NSRange
    let kind: Kind
}

struct MiniTokenizer: Sendable {
    enum Language: String, CaseIterable, Identifiable, Sendable {
        case swift
        case typescript
        case javascript
        case python
        case rust
        case go
        case java
        case kotlin
        case sql
        case json
        case shell
        case css

        var id: Self { self }
    }

    func tokenize(_ text: String, language: Language) -> [MiniToken] {
        let nsText = text as NSString
        var occupied = IndexSet()
        var tokens: [MiniToken] = []

        func capture(pattern: String, kind: MiniToken.Kind) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                return
            }
            for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
                let range = match.range
                guard range.location != NSNotFound else { continue }
                let indexes = IndexSet(integersIn: range.location..<(range.location + range.length))
                guard occupied.intersection(indexes).isEmpty else { continue }
                occupied.formUnion(indexes)
                tokens.append(MiniToken(range: range, kind: kind))
            }
        }

        capture(pattern: commentPattern(for: language), kind: .comment)
        capture(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, kind: .string)
        capture(pattern: #"\b\d+(?:\.\d+)?\b"#, kind: .number)
        capture(pattern: #"[{}()\[\],.;:]"#, kind: .punctuation)
        capture(pattern: #"[+\-*/=<>!&|%^~]+"#, kind: .operator)

        let keywords = keywordSet(for: language).joined(separator: "|")
        if !keywords.isEmpty {
            capture(pattern: #"\b(?:\#(keywords))\b"#, kind: .keyword)
        }
        let types = typeSet(for: language).joined(separator: "|")
        if !types.isEmpty {
            capture(pattern: #"\b(?:\#(types))\b"#, kind: .type)
        }

        return tokens.sorted { $0.range.location < $1.range.location }
    }

    private func commentPattern(for language: Language) -> String {
        switch language {
        case .python, .shell:
            return #"#.*$"#
        case .sql:
            return #"--.*$"#
        case .json:
            return #"$a"# // JSON has no comments.
        default:
            return #"//.*$"#
        }
    }

    private func keywordSet(for language: Language) -> [String] {
        switch language {
        case .swift:
            return ["let", "var", "if", "else", "for", "in", "func", "return", "guard", "switch", "case", "import"]
        case .typescript:
            return ["const", "let", "if", "else", "for", "in", "function", "return", "import", "from", "interface"]
        case .javascript:
            return ["const", "let", "if", "else", "for", "in", "function", "return", "import", "from", "class"]
        case .python:
            return ["def", "if", "else", "for", "in", "return", "import", "from", "class", "with", "as"]
        case .rust:
            return ["let", "mut", "if", "else", "for", "in", "fn", "return", "match", "impl", "use"]
        case .go:
            return ["func", "var", "const", "if", "else", "for", "range", "return", "package", "import", "type"]
        case .java:
            return ["class", "record", "public", "private", "static", "void", "return", "if", "else", "new", "import"]
        case .kotlin:
            return ["data", "class", "fun", "val", "var", "return", "if", "else", "when", "object", "sealed"]
        case .sql:
            return ["SELECT", "FROM", "WHERE", "WITH", "JOIN", "LEFT", "RIGHT", "GROUP", "ORDER", "BY", "AS"]
        case .json:
            return ["true", "false", "null"]
        case .shell:
            return ["if", "then", "else", "fi", "for", "in", "do", "done", "function"]
        case .css:
            return ["@media", "@supports", "from", "to"]
        }
    }

    private func typeSet(for language: Language) -> [String] {
        switch language {
        case .swift:
            return ["String", "Int", "Double", "Bool", "Void", "Any"]
        case .typescript:
            return ["string", "number", "boolean", "void", "unknown", "Promise"]
        case .javascript:
            return []
        case .python:
            return ["str", "int", "float", "bool", "list", "dict"]
        case .rust:
            return ["String", "str", "i32", "u64", "bool", "Vec"]
        case .go:
            return ["string", "int", "bool", "error", "byte", "rune"]
        case .java:
            return ["String", "Integer", "Long", "Boolean", "List", "Map"]
        case .kotlin:
            return ["String", "Int", "Long", "Boolean", "List", "Map"]
        case .sql, .json, .shell, .css:
            return []
        }
    }
}
