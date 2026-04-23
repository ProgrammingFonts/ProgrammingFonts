#!/usr/bin/env python3
"""Verify version metadata is consistent across the repository.

Sources of truth (must all agree):
    1. Sources/RootFontApp/Resources/AppVersion.json   -> canonical
    2. README.md                                       -> contains "v<version> (<build>)"
    3. Sources/RootFontApp/Models/AppMetadata.swift    -> fallbackVersion / fallbackBuild
    4. CHANGELOG.md                                    -> has "[<version>]" section

Exits non-zero when any source disagrees. Usage:
    python3 scripts/check-version.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VERSION_JSON = REPO_ROOT / "Sources/RootFontApp/Resources/AppVersion.json"
README = REPO_ROOT / "README.md"
METADATA = REPO_ROOT / "Sources/RootFontApp/Models/AppMetadata.swift"
CHANGELOG = REPO_ROOT / "CHANGELOG.md"


def load_canonical() -> tuple[str, str]:
    data = json.loads(VERSION_JSON.read_text(encoding="utf-8"))
    short = data.get("shortVersion", "").strip()
    build = data.get("buildNumber", "").strip()
    if not short or not build:
        sys.exit(f"AppVersion.json missing fields: {data!r}")
    return short, build


def check_readme(short: str, build: str) -> list[str]:
    text = README.read_text(encoding="utf-8")
    expected = f"v{short} ({build})"
    if expected not in text:
        return [f"README.md does not contain expected tag '{expected}'"]
    return []


def check_changelog(short: str) -> list[str]:
    if not CHANGELOG.exists():
        return [f"CHANGELOG.md not found at {CHANGELOG}"]
    text = CHANGELOG.read_text(encoding="utf-8")
    pattern = re.compile(rf"^##\s*\[{re.escape(short)}\]", re.MULTILINE)
    if not pattern.search(text):
        return [f"CHANGELOG.md is missing a '## [{short}]' section"]
    return []


def check_metadata_fallback(short: str, build: str) -> list[str]:
    text = METADATA.read_text(encoding="utf-8")
    errors: list[str] = []

    version_match = re.search(r'fallbackVersion\s*=\s*"([^"]+)"', text)
    build_match = re.search(r'fallbackBuild\s*=\s*"([^"]+)"', text)

    if not version_match or version_match.group(1) != short:
        errors.append(
            f"AppMetadata.fallbackVersion mismatch (expected {short!r}, "
            f"got {version_match.group(1) if version_match else 'missing'!r})"
        )
    if not build_match or build_match.group(1) != build:
        errors.append(
            f"AppMetadata.fallbackBuild mismatch (expected {build!r}, "
            f"got {build_match.group(1) if build_match else 'missing'!r})"
        )
    return errors


def main() -> int:
    short, build = load_canonical()
    errors = (
        check_readme(short, build)
        + check_metadata_fallback(short, build)
        + check_changelog(short)
    )

    if errors:
        print("Version inconsistency detected:")
        for err in errors:
            print(f"  - {err}")
        print(f"\nCanonical values from AppVersion.json: version={short!r}, build={build!r}")
        return 1

    print(f"Version consistent: v{short} (build {build})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
