#!/usr/bin/env python3

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
L10N_DIR = ROOT / "Sources" / "RootFontApp" / "Localization"
KEYS_FILE = L10N_DIR / "L10nKey.swift"
LOCALE_FILES = [
    L10N_DIR / "Locales" / "en.swift",
    L10N_DIR / "Locales" / "zh-Hans.swift",
    L10N_DIR / "Locales" / "zh-Hant.swift",
]


def parse_keys(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"^\s*case\s+([A-Za-z0-9_]+)\s*$", text, flags=re.MULTILINE))


def parse_locale_entries(path: pathlib.Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r"\.([A-Za-z0-9_]+)\s*:", text))


def main() -> int:
    all_keys = parse_keys(KEYS_FILE)
    has_error = False

    for locale_file in LOCALE_FILES:
        entries = parse_locale_entries(locale_file)
        missing = sorted(all_keys - entries)
        extra = sorted(entries - all_keys)

        if missing or extra:
            has_error = True
            print(f"[FAIL] {locale_file.relative_to(ROOT)}")
            if missing:
                print(f"  Missing keys ({len(missing)}): {', '.join(missing)}")
            if extra:
                print(f"  Extra keys ({len(extra)}): {', '.join(extra)}")
        else:
            print(f"[OK] {locale_file.relative_to(ROOT)}")

    if has_error:
        print("\nLocalization key check failed.")
        return 1

    print("\nLocalization key check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
