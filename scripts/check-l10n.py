#!/usr/bin/env python3
"""Validate localization files against the canonical key enum.

Checks performed per locale:
  1. Missing keys (defined in L10nKey.swift but absent from this locale).
  2. Extra keys (locale entries that no longer exist in L10nKey.swift).
  3. Placeholder consistency: printf-style placeholders (%@, %d, %1$d, etc.)
     must be identical across locales. Purely positional ordering differences
     (e.g. using %2$d before %1$d) are allowed because the multiset matches.

Exit code: 1 when any check fails, 0 otherwise.
"""

from __future__ import annotations

import pathlib
import re
import sys
from collections import Counter


ROOT = pathlib.Path(__file__).resolve().parents[1]
L10N_DIR = ROOT / "Sources" / "RootFontApp" / "Localization"
KEYS_FILE = L10N_DIR / "L10nKey.swift"
EN_FILE = L10N_DIR / "Locales" / "en.swift"
LOCALE_FILES = [
    EN_FILE,
    L10N_DIR / "Locales" / "zh-Hans.swift",
    L10N_DIR / "Locales" / "zh-Hant.swift",
    L10N_DIR / "Locales" / "ja.swift",
    L10N_DIR / "Locales" / "ko.swift",
]

# Matches printf-style placeholders such as %@, %d, %lld, %1$d, %2$@, %.2f.
PLACEHOLDER_PATTERN = re.compile(r"%(?:\d+\$)?[-+# 0]*\d*(?:\.\d+)?(?:ll|l|h|z|j|t)?[@diouxXeEfFgGaAcsp%]")
ENTRY_PATTERN = re.compile(
    r"\.(?P<key>[A-Za-z0-9_]+)\s*:\s*\"(?P<value>(?:[^\"\\]|\\.)*)\"",
)


def parse_keys(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"^\s*case\s+([A-Za-z0-9_]+)\s*$", text, flags=re.MULTILINE))


def parse_locale_entries(path: pathlib.Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    entries: dict[str, str] = {}
    for match in ENTRY_PATTERN.finditer(text):
        entries[match.group("key")] = match.group("value")
    return entries


def placeholders(value: str) -> list[str]:
    return PLACEHOLDER_PATTERN.findall(value)


def placeholder_signature(value: str) -> Counter:
    return Counter(placeholders(value))


def main() -> int:
    all_keys = parse_keys(KEYS_FILE)
    en_entries = parse_locale_entries(EN_FILE)
    expected_signatures = {key: placeholder_signature(val) for key, val in en_entries.items()}

    has_error = False

    for locale_file in LOCALE_FILES:
        entries = parse_locale_entries(locale_file)
        locale_keys = set(entries)
        missing = sorted(all_keys - locale_keys)
        extra = sorted(locale_keys - all_keys)

        placeholder_mismatches: list[str] = []
        for key, value in entries.items():
            expected = expected_signatures.get(key)
            if expected is None:
                continue
            got = placeholder_signature(value)
            if got != expected:
                expected_str = _fmt_counter(expected)
                got_str = _fmt_counter(got)
                placeholder_mismatches.append(
                    f"{key}: expected {expected_str}, got {got_str}"
                )

        if missing or extra or placeholder_mismatches:
            has_error = True
            print(f"[FAIL] {locale_file.relative_to(ROOT)}")
            if missing:
                print(f"  Missing keys ({len(missing)}): {', '.join(missing)}")
            if extra:
                print(f"  Extra keys ({len(extra)}): {', '.join(extra)}")
            if placeholder_mismatches:
                print(f"  Placeholder mismatches ({len(placeholder_mismatches)}):")
                for line in placeholder_mismatches:
                    print(f"    - {line}")
        else:
            print(f"[OK] {locale_file.relative_to(ROOT)}")

    if has_error:
        print("\nLocalization check failed.")
        return 1

    print("\nLocalization check passed.")
    return 0


def _fmt_counter(counter: Counter) -> str:
    if not counter:
        return "<none>"
    return ", ".join(f"{name}×{count}" for name, count in sorted(counter.items()))


if __name__ == "__main__":
    sys.exit(main())
