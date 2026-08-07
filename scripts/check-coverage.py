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
    files = [
        file
        for item in data.get("data", [])
        for file in item.get("files", [])
        if "/Sources/RootFontApp/" in file.get("filename", "").replace("\\", "/")
    ]
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
