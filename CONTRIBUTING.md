# Contributing to RootFont

Thank you for your interest in contributing to RootFont!

## Development Setup

RootFont is a pure Swift Package Manager macOS app. You do not need an
Xcode project file to build or run it.

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/rootfont.git
   cd rootfont
   ```

2. **Install Git hooks (required once per clone)**
   ```bash
   bash scripts/install-git-hooks.sh
   ```
   This wires up `pre-commit` to run:
   - `scripts/check-l10n.py` when a localization file is staged.
   - `scripts/check-version.py` when `AppVersion.json`, `README.md`,
     `AppMetadata.swift`, or `CHANGELOG.md` is staged.

3. **Build or run**
   ```bash
   swift build            # debug build
   swift run RootFontApp  # launch from terminal
   ```

   To produce a distributable `.app` bundle:
   ```bash
   bash scripts/build-app.sh
   ```
   The script reads `Sources/RootFontApp/Resources/AppVersion.json`
   and also embeds the current git short SHA into `Info.plist`.

4. **Xcode (optional)**
   ```bash
   xed .
   ```
   opens the package directly in Xcode. Do not commit a generated
   `*.xcodeproj` — the package manifest is the source of truth.

## Code Style

### Swift Style Guidelines
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4-space indentation
- Prefer explicit types over type inference for public APIs
- Use `guard` for early returns
- Prefer value types (struct, enum) over reference types (class)
- Keep views in `Sources/RootFontApp/Views`, models in `Models`, and
  pure business logic in `Services` so it can be tested off the main
  actor

### Naming Conventions
- Types: `PascalCase`
- Variables and functions: `camelCase`
- Constants: `camelCase` or `UPPER_CASE` for global constants
- Tests: `test<FunctionalityBeingTested>()`

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Add or update tests under `Tests/RootFontAppTests` where practical
   - Update `CHANGELOG.md` under the `[Unreleased]` section for any
     user-visible change
   - Update `README.md` and screenshots (see below) if UI changes

3. **Verify locally**
   ```bash
   swift build
   swift test
   python3 scripts/check-l10n.py
   python3 scripts/check-version.py
   ```

4. **Commit**
   - Keep commit subjects in imperative mood (`Add X`, `Fix Y`).
   - The tracked `commit-msg` hook strips any `Made-with: Cursor`
     trailer automatically; please do not add it back manually.
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Push and open a PR**
   - Push to your fork and open a PR against `main`.
   - Fill out the PR template.

## Testing

```bash
swift test
```

Tests run against both the `RootFontApp` module and the `Services`
layer (e.g. `FontFilterEngine`). Prefer adding new unit tests there
rather than inside the SwiftUI view layer.

## Localization

- Keys live in
  `Sources/RootFontApp/Localization/L10nKey.swift`.
- Each locale (`en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`) is a dictionary
  under `Sources/RootFontApp/Localization/Locales/`.
- Add every new key to **all** locales. `scripts/check-l10n.py`
  verifies missing/extra keys and printf placeholder consistency.

## Screenshots

- Place screenshots under `screenshots/v<version>/NN-<slug>.png`.
  Example: `screenshots/v0.2.0-beta/01-main-dark.png`.
- Run `python3 scripts/optimize-screenshots.py --check` before
  committing. Pass `--compress` (requires `pngquant`) to shrink PNGs
  in place if they exceed the recommended size.

## Documentation

- Update `README.md` for significant changes.
- Add inline documentation for public APIs.
- Update `CHANGELOG.md` for user-facing changes.
- Use Markdown for documentation files.

## License Agreement

By contributing to RootFont, you agree that your contributions will be
licensed under the Apache License, Version 2.0. This is automatic under
Section 5 of the Apache License.

You certify that:
1. The contribution is your original work
2. You have the right to submit the work under the Apache 2.0 license
3. The contribution does not violate any third-party rights

## Questions?

If you have questions about contributing, please:
1. Check existing issues and documentation
2. Open a new issue for discussion
3. Contact the maintainers at hi@rootfont.com
