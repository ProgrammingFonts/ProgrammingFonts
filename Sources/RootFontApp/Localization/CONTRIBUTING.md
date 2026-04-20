# Localization Contribution Guide

This document explains how to add a new UI language to RootFont.

## Structure

Localization code lives under:

- `Localization/AppLanguage.swift`
- `Localization/L10nKey.swift`
- `Localization/L10n.swift`
- `Localization/Locales/*.swift`

Each locale file contains a dictionary:

- key: `L10nKey`
- value: localized UI text

English (`en.swift`) is the fallback source of truth.

## Add a New Language (3 Steps)

1. **Add language enum case**
   - Edit `Localization/AppLanguage.swift`
   - Add a new `AppLanguage` case with BCP-47 style code (example: `fr`, `ja`, `de`)
   - Add user-visible language name in `displayName`
   - Add `contributionFileName`

2. **Create locale file**
   - Add `Localization/Locales/<code>.swift`
   - Follow existing naming style (example: `fr.swift`)
   - Start from `Localization/Locales/_template.swift` for fastest setup
   - Define `enum L10nXX` with `static let entries: [L10nKey: String]`
   - Translate all values

3. **Wire resolver**
   - Edit `Localization/L10n.swift`
   - Add switch branch mapping new `AppLanguage` to the new locale table

## Naming Conventions

- Use stable language code file names, e.g.:
  - `en.swift`
  - `zh-Hans.swift`
  - `zh-Hant.swift`
- Keep enum names consistent and readable, e.g.:
  - `L10nEN`
  - `L10nZHHans`
  - `L10nZHHant`
- Do not remove or rename existing `L10nKey` cases unless doing a coordinated refactor.

## Translation Rules

- Keep placeholders and punctuation semantically equivalent.
- Keep product name `RootFont` unchanged.
- Use concise UI text; avoid overlong labels.
- Prefer consistency with existing terms (`Settings`, `Favorites`, `Preview`, etc.).

## Validation Checklist

Before opening a PR, verify all of the following:

- [ ] New language appears in Settings -> Language picker.
- [ ] App can switch to the new language at runtime.
- [ ] Language selection persists after app restart.
- [ ] No missing keys in the new locale dictionary.
- [ ] `swift test` passes.
- [ ] `swift build` passes.

## Notes

- Missing keys currently fall back to English in `L10n.tr`.
- If you add new UI text, first add a new `L10nKey`, then update all locale files.
