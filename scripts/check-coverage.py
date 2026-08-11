#!/usr/bin/env python3
"""Fail when RootFontApp line coverage falls below the configured baseline."""

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("coverage_json", type=Path)
    parser.add_argument("--minimum", type=float, required=True)
    args = parser.parse_args()

    data = json.loads(args.coverage_json.read_text())
    excluded = (
        "/Sources/RootFontApp/Views/",
        "/Sources/RootFontApp/Localization/Locales/",
        "/Sources/RootFontApp/Localization/L10nKey.swift",
        "/Sources/RootFontApp/RootFontApp.swift",
    )
    files = []
    for item in data.get("data", []):
        for file in item.get("files", []):
            filename = file.get("filename", "").replace("\\", "/")
            if "/Sources/RootFontApp/" not in filename:
                continue
            if any(path in filename for path in excluded):
                continue
            files.append(file)
    covered = sum(file["summary"]["lines"]["covered"] for file in files)
    total = sum(file["summary"]["lines"]["count"] for file in files)
    percentage = 100.0 if total == 0 else covered * 100.0 / total
    print(f"Coverage: {percentage:.2f}% ({covered}/{total}); minimum: {args.minimum:.2f}%")
    if percentage + 1e-9 < args.minimum:
        print("Coverage gate failed.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
