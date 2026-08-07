# Development TODO

This file tracks work that remains after the P0/P1 refactoring completed in
August 2026. Tasks are ordered by priority and should be completed from top to
bottom within each section unless a dependency says otherwise.

## P1 — Architecture and test safety

- [ ] Extract `FontCatalogCoordinator` from `FontBrowserViewModel`.
  - [x] Own staged catalog task execution, partial results, progress, errors,
    and stale-load cancellation.
  - [ ] Own watcher
    events, reload coalescing, and managed-font refreshes.
  - Preserve the current UI-facing API and loading behavior.
  - Add tests for success, failure, partial results, watcher bursts, and stale
    load cancellation.
- [ ] Extract `FontSelectionController` from `FontBrowserViewModel`.
  - [x] Own adjacent navigation, batch selection, favorites, and recents
    transformations.
  - [ ] Own selected-font state and selection recovery orchestration.
  - Add tests for duplicate recents, filtered selection, batch operations, and
    selection recovery after catalog/filter changes.
- [ ] Extract `FontBrowserPreferencesController`.
  - [x] Centralize restoration of language, appearance, preview, filter,
    snippet, collection, score, and feature preferences.
  - [ ] Own all preference writes currently performed by the view model.
  - [x] Keep decoding backward compatible with existing stored preferences.
  - [x] Add corrupted-data and legacy-data migration tests.
- [ ] Reduce `FontBrowserViewModel` from about 1,112 lines to 700–850 lines.
  - Keep it as the UI-facing composition layer instead of moving business
    rules back into it.
- [x] Add focused tests for `FontFilterCoordinator`.
  - Verify cache hits preserve ordering.
  - Verify invalidation forces recomputation.
  - Verify a newer asynchronous request supersedes an older request.
  - Verify cancelled work cannot commit stale results.

## P1 — SwiftUI view decomposition

- [ ] Continue splitting `FontListView` (currently about 868 lines).
  - Extract the toolbar and filter summary.
  - Extract list rows and grid content.
  - Extract batch actions and organization menus.
  - Keep display/density preferences in one clearly owned component.
- [ ] Continue splitting `FontPreviewView` (currently about 785 lines).
  - [x] Extract surface, size, wrapping, and typography controls.
  - [ ] Extract preview text editing and code-language controls.
  - Extract typography and OpenType controls.
  - Extract code/sample preview surfaces.
  - Move specimen export and activation presentation state into focused
    helpers where practical.
- [ ] Build the app and manually verify grid/list selection, search focus,
  preview editing, OpenType toggles, and export dialogs after the split.

## P2 — Coverage and engineering quality

- [ ] Raise line coverage from the current 25.29% baseline.
  - Prioritize coordinators, persistence, activation, importing, filtering,
    and catalog lifecycle code.
  - [x] Raise the immediate CI threshold from 24% to 25%.
  - [ ] Raise the CI threshold to 30% once the suite is stable above that value.
  - Raise it toward 40% in a later dedicated test pass.
- [ ] Add stress and regression coverage.
  - [ ] Rapid font-folder change bursts.
  - [x] Rapid filter requests, cancellation, and stale-result suppression.
  - [ ] Rapid search and sort changes through the view model.
  - Repeated programming-score weight changes.
  - Large font catalogs, including memory and filter-time checks.
- [ ] Introduce SwiftFormat with a pinned version and a checked-in config.
  - Start by checking changed files to avoid a repository-wide formatting
    rewrite.
- [ ] Introduce SwiftLint with a pinned version and a minimal warning policy.
  - Enable rules incrementally and keep CI output actionable.
- [ ] Split growing test files by component, especially
  `FontBrowserSupportTests.swift`.
- [ ] Add lightweight cache diagnostics for development builds where they can
  validate hit rates without affecting release performance.

## Deferred release work

These tasks intentionally remain blocked until company developer credentials
and release ownership are available.

- [ ] Configure the company Developer ID identity and bundle capabilities.
- [ ] Sign the application and embedded artifacts.
- [ ] Submit the application for Apple notarization and staple the result.
- [ ] Produce and verify the distributable app/archive or installer.
- [ ] Document the company release procedure and credential ownership.

Do not start the deferred release tasks with personal credentials.
