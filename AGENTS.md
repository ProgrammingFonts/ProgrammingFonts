# AGENTS.md

Guidance for AI agents (opencode, Claude Code, etc.) working on rootfont.

## Build / test / lint commands

- Build app: `swift run RootFontApp`
- Build for tests: `swift build --build-tests`
- Run tests: `swift test --parallel --enable-code-coverage`
- Lint: `bash scripts/check-swift-style.sh`
- Localization check: `python3 scripts/check-l10n.py`
- Version check: `python3 scripts/check-version.py`
- Screenshot check: `python3 scripts/optimize-screenshots.py --check`
- Build .app bundle: `bash scripts/build-app.sh`

Always run `swift build` after non-trivial changes, and `swift test` when
tests are touched. The CI coverage gate is 70% for core logic (Views,
Localization/Locales, L10nKey.swift, and RootFontApp.swift are excluded).

## Toolchain

- macOS 14+, Xcode 15+, Swift 6.0+ (Swift 6.2+ recommended).
- Use the Xcode toolchain, not standalone Command Line Tools:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- Linux / Command-Line-Tools-only builds are NOT supported (CoreText/AppKit).

## Architecture

- `Sources/RootFontApp/` is the single executable target.
- `Services/` — business logic, all `Sendable` or `@MainActor`-isolated.
- `ViewModels/` — `@MainActor` `ObservableObject` plus per-feature
  extensions (`+Collections`, `+Health`, `+Presentation`).
- `Views/` — SwiftUI. `FontList/` and `FontPreview/` hold split-out subviews.
- `Models/` — value types (`FontItem`, `ProgrammingProfile`, `AppError`).
- `Localization/` — `L10nKey` enum + per-locale files; new keys must be
  added to every `Localization/Locales/*.swift` file (CI checks this via
  `scripts/check-l10n.py`).

## Conventions

- No comments unless requested. Existing doc comments are fine to keep.
- Errors flow as `AppError` (see `Models/AppError.swift`); user-facing
  messages are produced by `L10nKey` lookup in the view layer, not by
  services.
- Logging goes through `AppLog` (`Services/AppLog.swift`) — never
  `print()`/`NSLog`.
- Caches should be `actor` or use `os_unfair_lock`-backed `LockedLRUCache`;
  avoid new `@unchecked Sendable` + `NSLock` patterns.
- Persisted stores (`PreferencesStore`, `ScoreManifestStore`,
  `FontActivationService`) carry a `version` field; bump it on schema
  changes and add migration code.
- `swift-tools-version: 6.0` — strict concurrency is on. New types
  touching background tasks must be `Sendable`.

## Committing

- Do not commit unless the user explicitly asks.
- Do not amend or force-push.
- Keep `CHANGELOG.md` in sync with user-visible changes.
- Run `bash scripts/check-swift-style.sh` before committing; the CI
  `check-swift-style.sh` step is required.
