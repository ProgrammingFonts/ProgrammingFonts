# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- `FontBrowserViewModel` delegates preview presets, filter-result caching,
  preference coding, and detached catalog loading to focused support types
  while preserving its existing UI-facing API.
- Product display name rebranded from `RootFont` to `rootfont` across UI
  strings, docs, Application Support / Fonts paths, and the packaged app
  name. Code module/target names such as `RootFontApp` are unchanged.

### Added
- UI locales for French (`fr`), German (`de`), and Spanish (`es`).

### Fixed
- Font-folder watching now serializes FSEvents lifecycle state, retains its
  callback context safely, avoids duplicate nested watches, and queues a reload
  when a catalog change arrives during an active load.
- Font-health duplicate detection distinguishes weight tiers, reducing false
  positives for legitimate members of the same family.
- Specimen and comparison exports report write failures instead of showing a
  false success message; score-cache write failures no longer poison memory.
- Managed-font reconciliation failures at launch are surfaced as a dismissible
  warning instead of being silently ignored.
- CI coverage summaries now include production sources only, and generated
  coverage artifacts are ignored locally.
- Font activation and installation now roll back registration and copied files
  when manifest persistence fails; uninstall restores the font when it cannot
  commit the updated managed-font state, and rollback failures are surfaced.
- Swift 6.2+ `SendingRisksDataRace` in `FontBrowserViewModel.load()` and
  `applyFilters()`: font load and filter work stay on `Task.detached` with
  Sendable inputs; UI updates run from `@MainActor` tasks without sending
  `self` across isolation boundaries (related to issue #56).
- Catalog load progress/partial callbacks use a `CatalogLoadBridge` so
  `@Sendable` closures passed to `Task.detached` never capture
  `FontBrowserViewModel` directly.
- Swift 6 compile errors in `FontActivationService` and
  `ScoreManifestStore` by storing in-memory caches in locked reference
  types instead of mutating `struct` state from non-`mutating` methods.
- `FontBrowserViewModelTests` now use async `waitForLoad` with
  `Task.yield` instead of `RunLoop` polling so `swift test` reliably waits
  for MainActor-scheduled catalog loads.

### Changed
- Programming-fit sort and recommended/avoid filters reuse cached
  `programmingScore` totals instead of recomputing score breakdowns each pass.
- Tag filtering uses an inverted `tag → fontIDs` index; sidebar tag names are
  cached; filter signatures and inputs share one collection/tag snapshot.
- Staged catalog loads skip a second full search-index / weight-coverage
  rebuild when font IDs are unchanged after enrichment.
- Coverage query trimming and search prepare happen only when those inputs
  change; list/grid highlighting reuses the prepared query and caches
  `NSFont` on grid cards.
- CI runs `swift test --parallel` and drops verbose package resolve/build
  logging now that builds are stable.
- `FontFilterEngine` reuses precomputed `FamilyWeightCoverage` and glyph
  coverage cache snapshots so programming-mode filters and detached filter
  tasks avoid rebuilding weight tiers or re-querying CoreText per pass.
- Catalog load skips rescoring and score-manifest writes when every font is
  already cached and default score weights are in effect.
- `FontCatalogService` returns early on fully cached loads without
  rebuilding the score manifest dictionary.
- Search query normalization is prepared once per keystroke and reused for
  filtering and list highlighting.
- CI SwiftPM cache is re-enabled; diagnostic cache wipes removed now that
  builds are stable.
  activation manifest from disk on every filter pass.
- `FontActivationService` keeps the activation manifest in memory and
  refreshes the cache on save, avoiding repeated disk reads from
  `isManaged`, `managedCount`, and `managedFontIDs`.
- Catalog reload refreshes managed-font IDs at the start of `load()`.
- `ScoreManifestStore` caches score manifest entries in memory and updates
  the cache on save, avoiding repeated reads of `scores.json` during a
  single catalog session.
- GitHub Actions CI uploads `swift-build-log` on failure, prints the full
  log in the job summary, and sets `DEVELOPER_DIR` for build/test steps.
- Pre-commit hook runs `optimize-screenshots.py --check` when screenshot
  PNGs are staged.
- Warm catalog loads skip a second programming-score pass and redundant
  score-manifest writes when every font is already cached.
- `FontFilterEngine` builds family weight coverage only when programming
  sidebar filters or programming-fit sort require it.
- `FontActivationService` resolves font URLs through `FontURLIndex` for
  O(1) lookup instead of scanning the full font list.
- CI caches SwiftPM artifacts and skips macOS jobs for docs-only changes.
- Fully cached catalog loads skip the initial programming-score pass as well.
- `FontActivationService` skips activation-manifest writes when content is
  unchanged.
- Filter-result cache signatures include score weights only when programming
  sort or sidebar filters need them; favorite, recent, and managed
  signatures are scoped to their active sidebar filters.
- Selecting fonts and toggling favorites no longer refilters the list unless
  the matching sidebar filter is active.
- Programming workspace caches the monospaced font subset instead of filtering
  the full catalog on every filter pass.
- CI cancels superseded workflow runs and bumps `actions/checkout` and
  `actions/cache` to v5; Dependabot drops invalid assignee placeholder.
- Re-enabled the `license-check` GitHub Actions workflow with weekly
  schedule, push/PR triggers on `master`, and docs-only path ignores.
- Bumped GitHub Actions dependencies: `actions/checkout` v7,
  `actions/cache` v6, `fossa-contrib/fossa-action` v4.
- CI runs on `macos-15` for a newer Swift/Xcode toolchain.
- Filter commits track `filteredFontIDs` for O(1) selection visibility
  checks; recent sidebar filter uses a `Set` for membership lookups.
- Removed duplicate appearance application at window `onAppear` (init
  already applies stored appearance).

### Added
- Manual collections: create named font lists, filter by collection in the
  sidebar, and add or remove fonts via context menus.
- Font tags: tag the selected font from the sidebar, filter by tag, and
  toggle tags on fonts from context menus. Assignments persist in
  UserDefaults.

### Changed
- CI SwiftPM cache key is scoped to `macos-15` to avoid stale artifacts
  from older runners; build logs upload on failure for easier diagnosis.
- License Check validates the root `LICENSE` file instead of scanning the
  whole tree (avoids false positives from `NOTICE` and docs).
- `SearchMatcher.PreparedQuery` and `FontItem` are explicitly `Sendable`.
- Manual collection/tag filter cache signatures track membership content.
- Filter enums (`SidebarFilter`, `SortOption`, `WorkspaceModule`) moved out
  of `@MainActor` `FontBrowserViewModel` so Swift 6 treats them as
  unconditionally `Sendable` in `FontFilterEngine` detached tasks.
- SwiftPM targets compile in Swift 5 language mode under the Swift 6
  toolchain so CI matches typical Xcode project settings.

### Documentation
- README documents full Xcode requirement, `xcode-select` verification,
  XCTest troubleshooting, `build-app.sh`, bug-report guidance, and CI /
  license badges.
- CONTRIBUTING, screenshot conventions, and issue/PR templates aligned with
  the `master` default branch and v0.3.0-alpha paths.

## [0.3.0-alpha] - 2026-06-16

### Added
- Programming workspace module with Library / Programming sidebar switch;
  Programming mode scopes to monospaced fonts and defaults sort to
  programming fit.
- Sidebar filters: Recommended for code, Avoid for code, and Managed by
  rootfont.
- Programming suitability scoring (`ProgrammingScoreEngine`) with S / A /
  B / C / NR grades across ten weighted factors: monospace baseline,
  glyph disambiguation, ligature support, stylistic flexibility, box
  drawing, Powerline glyphs, Nerd Font coverage, variable font, language
  coverage, and weight variety.
- `FontFeatureInspector` and `FontMetricsProbe` for OpenType feature
  detection, confusable-pair distances, and ASCII advance variance.
- `ScoreManifestStore` persists profiles, metrics, and scores to
  `~/Library/Application Support/rootfont/scores.json`, keyed by file
  modification time for automatic invalidation.
- Score breakdown UI with per-factor progress bars, grade badges, Why
  popovers, and low-grade improvement hints.
- Configurable score weights in Settings: Default, Terminal Heavy, IDE
  Heavy, and Minimalist presets plus ten independent sliders (0–40).
- `FontCompareView` with side-by-side, overlay (opacity + visibility),
  glyph zoom, and outline-diff modes; score delta, factor deltas, and
  language-coverage diff.
- Sample / Code preview surface toggle with `MiniTokenizer` syntax
  highlighting for twelve languages and `SnippetCatalog` semantic /
  native snippet strategies.
- `OpenTypeFeatureBinder` for live ligature, slashed-zero, and stylistic-
  set preview; per-font `FontFeaturePreferences` persistence.
- `FontActivationService`: session activate, user-scope install to
  `~/Library/Fonts/rootfont/`, uninstall, startup reconcile, and managed-
  font sidebar filter.
- `EditorConfigExporter` one-click snippets for VS Code, Cursor,
  Alacritty, Kitty, Warp, and Zed.
- Preview header actions: copy PostScript name, copy editor config, open
  in Font Book, activate / install / uninstall, open managed-fonts folder.
- Staged catalog loading with two-phase progress UI and partial results
  before enrichment finishes.
- `FontURLIndex` shared cache for `CTFontManagerCopyAvailableFontURLs`.
- Programming grade badges on grid cards.
- GitHub Actions CI on `macos-14`: `swift build`, `swift test`,
  `check-l10n.py`, `check-version.py`.
- Screenshots for v0.3.0-alpha (dark and light main window).
- Test suites for scoring, activation, compare, snippets, metrics, and
  filter performance (~80 cases across 16 files).

### Changed
- `FontPreviewView` split into `FontPreviewHeaderSection`,
  `FontPreviewProgrammingPanel`, `FontPreviewFactorLabels`,
  `FontPreviewTextRendering`, and `FontPreviewTypes`.
- `FontCatalogService` integrates staged load, score cache read/write,
  and enrichment progress reporting.
- `FontBrowserViewModel` extended with workspace module, score weights,
  managed-font state, and load-progress publishing.
- `FontFilterEngine` supports programming-fit sort, recommended/avoid
  filters, and managed-font filtering.
- Expanded sidebar and font-list row hit targets and vertical padding for
  more reliable selection.
- README updated for v0.3.0-alpha with What's New, features, and new
  screenshot paths.

### Removed
- Legacy `Sources/FontManager.swift` singleton (superseded by
  `FontCatalogService` + `FontURLIndex`).

### Localization
- ~155 new `L10nKey` entries for programming workspace, scoring,
  compare, activation, editor export, and code preview across all five
  locales (`en`, `zh-Hans`, `zh-Hant`, `ja`, `ko`).

## [0.2.0-beta] - 2026-04-23

### Added
- About panel now shows the git short SHA under the build number and
  ships two new copy actions: "Copy Version" pastes a diagnostics
  line (`rootfont v<version> (<build>) · commit <sha>`), "Copy System
  Info" additionally appends `macOS x.y.z · <arch> · <language> ·
  <appearance>`.
- `scripts/build-app.sh` embeds `RootFontCommitSha` into the packaged
  `Info.plist` so release builds self-identify without needing the
  working tree.
- `scripts/check-version.py` now also verifies that `CHANGELOG.md`
  contains a matching `## [<version>]` section.
- Tracked git hooks under `scripts/hooks/`: `pre-commit` runs
  `check-l10n.py` on staged localization files and `check-version.py`
  on staged `AppVersion.json`, `README.md`, `AppMetadata.swift`, or
  `CHANGELOG.md`. Install with `bash scripts/install-git-hooks.sh`.
- `scripts/optimize-screenshots.py` for screenshot layout / size
  validation and optional `pngquant` compression, documented in
  `screenshots/README.md`.
- `accessibilityLabel` on the favorite star buttons (grid + list) and
  on the toolbar preview toggle so VoiceOver announces them.
- New localization keys `favoriteAdd`, `favoriteRemove`,
  `previewTruncatedInfo`, `aboutCopySystemInfo`,
  `aboutSystemInfoCopied` across all five locales.

### Changed
- Font filter + sort + alias collapse + glyph coverage extracted into
  a `Sendable` `FontFilterEngine`. Large catalogs run through
  `Task.detached` with snapshotted inputs so the main actor stays
  responsive while typing.
- Up to eight recent filter results are cached by a signature that
  covers query, coverage text, source/style/sidebar filter, sort,
  language, catalog epoch, and favorites/recents fingerprints. Cache
  invalidates automatically on catalog reload.
- Grid column count is cached in `@State`, so `LazyVGrid.columns` only
  reshapes when the target column count actually changes — smooths
  dragging the list preview-size slider at high values.
- Preview soft-wrap (ZWSP) now only applies up to 400 characters;
  longer text defers to the native layout engine. Any preview text
  over 2000 characters is truncated with a localized hint.
- `WindowAccessor` uses a per-view, `@MainActor`-isolated coordinator
  that self-cleans on `NSWindow.willCloseNotification`, replacing the
  previous global set and fixing Swift 6 concurrency warnings.
- `scripts/check-l10n.py` now also enforces printf placeholder
  consistency (e.g. `%@`, `%1$d`) across every locale.
- CONTRIBUTING.md rewritten for the SwiftPM layout (`swift build`,
  `swift run`, `swift test`), documents the git hook install step,
  and references the new validation scripts.

### Localization
- Migrated the last hardcoded `Add favorite` / `Remove favorite`
  tooltips to localized keys; all five locales updated.

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
