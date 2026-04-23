# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0-alpha] - 2026-04-22

### Added
- Closable right-side font preview panel: drag the divider inward to
  collapse it, and use the toolbar button to restore. Sensitivity is
  tuned to ignore the initial expand animation.
- Adjustable list preview size (2–500 px) that also drives a dynamic
  grid column count — smaller sizes pack more cards per row, the
  largest size settles at two cards per row.
- Japanese (`ja`) and Korean (`ko`) localization, with matching preset
  sample texts and font-name search that understands Hangul choseong
  (초성) queries.
- About panel: bundled logo via `Bundle.module`, short git commit SHA,
  one-click "Copy Version" diagnostics line, and a "Copy System Info"
  button that pastes OS + architecture + language + appearance.
- Version tooling: `Sources/RootFontApp/Resources/AppVersion.json`
  drives both runtime reads and the packaging script; added
  `scripts/check-version.py` plus a tracked `scripts/hooks/pre-commit`
  for automatic consistency checks.
- Screenshot hygiene: `screenshots/v<version>/NN-<slug>.png` layout,
  `screenshots/README.md` conventions, and
  `scripts/optimize-screenshots.py` for validation and optional
  `pngquant` compression.

### Changed
- Font filtering and sorting move off the main actor via
  `Task.detached` for large catalogs, with an 8-entry result cache
  keyed by filter signature; small catalogs stay synchronous to avoid
  task overhead.
- Preview uses ZWSP soft-wrap only up to 400 characters, trusts the
  native layout engine beyond that, and truncates >2000-character
  input with a localized hint.
- `WindowAccessor` is now coordinator-backed per view and cleans up on
  `NSWindow.willCloseNotification` instead of leaking identifiers in a
  global set.
- Grid column count is cached in `@State` so `LazyVGrid.columns` only
  reshapes when the count actually changes, smoothing large-preview
  drag behavior.
- Build script (`scripts/build-app.sh`) now embeds git short SHA into
  `Info.plist` (`RootFontCommitSha`) alongside the existing version
  keys.

### Fixed
- Removed the ghost divider/tick-marks under the list and preview
  sliders by disabling `NSToolbar.showsBaselineSeparator` and
  dropping the `step` parameter in favor of a rounded binding.
- Prevented the inspector from collapsing during its expansion
  animation via hysteresis + debounce.

### Localization
- Extended `scripts/check-l10n.py` with printf placeholder
  consistency, reaching five locales: `en`, `zh-Hans`, `zh-Hant`,
  `ja`, `ko`. Migrated the last hardcoded English strings
  (`Add favorite` / `Remove favorite`) behind new keys.

## License Notice

This project is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---

## How to Update This Changelog

For new versions, add a new `## [x.y.z] - YYYY-MM-DD` section. Use the following categories:

- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for any bug fixes
- `Security` in case of vulnerabilities