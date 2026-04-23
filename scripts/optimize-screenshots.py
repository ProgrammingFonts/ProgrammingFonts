#!/usr/bin/env python3
"""Validate and optionally compress RootFont screenshot assets.

Screenshot directory convention (see screenshots/README.md):

    screenshots/
    └── v<version>/
        └── NN-slug.png

Checks:
    * files live inside a version-prefixed directory
    * names match `NN-<kebab-slug>.png`
    * lowercase `.png` extension
    * size warning / error thresholds

Usage:
    python3 scripts/optimize-screenshots.py --check
    python3 scripts/optimize-screenshots.py --compress
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SHOT_ROOT = REPO_ROOT / "screenshots"
VERSION_DIR_PATTERN = re.compile(r"^v\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?$")
FILE_PATTERN = re.compile(r"^\d{2}-[a-z0-9]+(?:-[a-z0-9]+)*\.png$")

WARN_BYTES = 800 * 1024
ERROR_BYTES = 2 * 1024 * 1024


def discover_files() -> list[Path]:
    return sorted(p for p in SHOT_ROOT.rglob("*.png") if p.is_file())


def validate(paths: list[Path]) -> list[str]:
    problems: list[str] = []
    if not paths:
        problems.append(f"{SHOT_ROOT.relative_to(REPO_ROOT)} contains no PNG files.")
        return problems

    for path in paths:
        rel = path.relative_to(REPO_ROOT)
        relative_to_shots = path.relative_to(SHOT_ROOT).parts
        if len(relative_to_shots) != 2:
            problems.append(
                f"{rel}: files must live exactly one level deep "
                f"(e.g. screenshots/v0.2.0-beta/01-main-dark.png)."
            )
            continue

        version_folder, file_name = relative_to_shots
        if not VERSION_DIR_PATTERN.match(version_folder):
            problems.append(
                f"{rel}: parent folder '{version_folder}' must look like 'v0.2.0-beta'."
            )
        if not FILE_PATTERN.match(file_name):
            problems.append(
                f"{rel}: file name must match 'NN-<kebab-slug>.png' (lowercase)."
            )
        size = path.stat().st_size
        if size > ERROR_BYTES:
            problems.append(f"{rel}: {_fmt_size(size)} exceeds {_fmt_size(ERROR_BYTES)} hard limit.")
        elif size > WARN_BYTES:
            problems.append(
                f"{rel}: {_fmt_size(size)} exceeds {_fmt_size(WARN_BYTES)} recommended limit "
                f"(run with --compress or use ImageOptim)."
            )

    return problems


def compress(paths: list[Path]) -> bool:
    if not shutil.which("pngquant"):
        print(
            "pngquant is not installed. Install it (e.g. `brew install pngquant`) "
            "or compress manually with ImageOptim.",
            file=sys.stderr,
        )
        return False

    any_compressed = False
    for path in paths:
        original = path.stat().st_size
        if original <= WARN_BYTES:
            continue
        print(f"Compressing {path.relative_to(REPO_ROOT)} ({_fmt_size(original)})…")
        result = subprocess.run(
            [
                "pngquant",
                "--force",
                "--skip-if-larger",
                "--quality=70-90",
                "--strip",
                "--output",
                str(path),
                str(path),
            ],
            check=False,
        )
        if result.returncode not in (0, 98, 99):
            print(f"  pngquant failed with exit code {result.returncode}", file=sys.stderr)
            continue
        new_size = path.stat().st_size
        if new_size < original:
            any_compressed = True
            print(
                f"  {_fmt_size(original)} -> {_fmt_size(new_size)} "
                f"({(1 - new_size / original) * 100:.1f}% smaller)"
            )
    return any_compressed


def _fmt_size(value: int) -> str:
    if value >= 1024 * 1024:
        return f"{value / 1024 / 1024:.2f} MB"
    if value >= 1024:
        return f"{value / 1024:.1f} KB"
    return f"{value} B"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate names and sizes only")
    parser.add_argument("--compress", action="store_true", help="run pngquant on oversized PNGs")
    args = parser.parse_args()

    if not args.check and not args.compress:
        args.check = True

    paths = discover_files()
    problems = validate(paths)

    if problems:
        print("Screenshot validation issues:")
        for line in problems:
            print(f"  - {line}")
        if args.check:
            return 1

    if args.compress:
        if compress(paths):
            print("Compression finished. Re-run --check to confirm sizes.")
        else:
            print("No images required compression.")

    if not problems:
        print(f"All {len(paths)} screenshots look good.")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
