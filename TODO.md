# Development TODO

This file tracks work that remains after the P0/P1 refactoring completed in
August 2026. Tasks are ordered by priority and should be completed from top to
bottom within each section unless a dependency says otherwise.

## P0 — Architecture and test safety

- [x] Extract `FontCatalogCoordinator` from `FontBrowserViewModel`.
  - [x] Own staged catalog task execution, partial results, progress, errors,
    and stale-load cancellation.
  - [x] Own watcher
    events, reload coalescing, and managed-font refreshes.
  - Preserve the current UI-facing API and loading behavior.
  - Add tests for success, failure, partial results, watcher bursts, and stale
    load cancellation.
- [x] Extract `FontSelectionController` from `FontBrowserViewModel`.
  - [x] Own adjacent navigation, batch selection, favorites, and recents
    transformations.
  - [x] Own selected-font resolution and selection recovery orchestration.
  - Add tests for duplicate recents, filtered selection, batch operations, and
    selection recovery after catalog/filter changes.
- [x] Extract `FontBrowserPreferencesController`.
  - [x] Centralize restoration of language, appearance, preview, filter,
    snippet, collection, score, and feature preferences.
  - [x] Own all preference writes previously performed by the view model.
  - [x] Keep decoding backward compatible with existing stored preferences.
  - [x] Add corrupted-data and legacy-data migration tests.
- [x] Reduce `FontBrowserViewModel` to 770 lines (target: 700–850 lines).
  - Keep it as the UI-facing composition layer instead of moving business
    rules back into it.
- [x] Add focused tests for `FontFilterCoordinator`.
  - Verify cache hits preserve ordering.
  - Verify invalidation forces recomputation.
  - Verify a newer asynchronous request supersedes an older request.
  - Verify cancelled work cannot commit stale results.

## P1 — SwiftUI view decomposition

- [x] Continue splitting `FontListView` (now about 798 lines).
  - List rows and grid cards remain focused view types.
  - [x] Extract batch actions and organization menus.
  - Display/density preferences remain owned by the list composition view.
- [x] Continue splitting `FontPreviewView` (now about 715 lines).
  - [x] Extract surface, size, wrapping, and typography controls.
  - [x] Extract code-language, snippet, typography, and surface controls.
  - Existing focused subviews own OpenType, programming, variable-font, text
    rendering, header/export, and status sections.
- [x] Build and launch-smoke-test the app after the split; interaction state is
  covered by ViewModel/controller regression tests.

## P2 — Coverage and engineering quality

- [x] Raise testable core-logic line coverage to 72.64%.
  - Prioritize coordinators, persistence, activation, importing, filtering,
    and catalog lifecycle code.
  - [x] Raise the immediate CI threshold from 24% to 25%.
  - [x] Raise the CI threshold to 70% for core logic; declarative SwiftUI,
    generated localization tables, and the app entry point are excluded.
- [x] Add stress and regression coverage.
  - [x] Rapid font-folder change bursts.
  - [x] Rapid filter requests, cancellation, and stale-result suppression.
  - [x] Rapid search and sort changes through the view model.
  - [x] Repeated programming-score weight changes.
  - [x] Large-font-catalog filter-time checks.
- [x] Introduce SwiftFormat 0.55.0 with a checked-in minimal config.
- [x] Introduce SwiftLint 0.65.0 with a checked-in minimal warning policy.
- [x] Split `FontBrowserSupportTests.swift` into component test files.
- [x] Add Debug-only cache hit, miss, and eviction diagnostics.

## Deferred release work

These tasks intentionally remain blocked until company developer credentials
and release ownership are available.

- [ ] Configure the company Developer ID identity and bundle capabilities.
- [ ] Sign the application and embedded artifacts.
- [ ] Submit the application for Apple notarization and staple the result.
- [ ] Produce and verify the distributable app/archive or installer.
- [ ] Document the company release procedure and credential ownership.

Do not start the deferred release tasks with personal credentials.
