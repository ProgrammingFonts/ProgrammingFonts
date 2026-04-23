# RootFont Screenshots

This directory holds the marketing / documentation screenshots referenced
from the repository's `README.md`. Follow the conventions below so the
repository size stays reasonable and images remain easy to audit.

## Directory layout

```
screenshots/
├── v<version>/        # one folder per released version
│   ├── 01-<slug>.png
│   ├── 02-<slug>.png
│   └── ...
```

- `<version>` matches the tag produced from `AppVersion.json`, for
  example `v0.2.0-beta`.
- Each image starts with a **two-digit numeric prefix** (`01-`, `02-`,
  …) that determines the display order in `README.md`.
- Use **kebab-case slugs** that describe the view at a glance:
  `01-main-dark.png`, `02-search-korean.png`, `03-about-panel.png`.
- Keep image extensions lowercase (`.png`).

## Size & format

- Capture at the native retina resolution, then scale to at most
  `2560×1600` (window captures are fine without scaling).
- Prefer **PNG**. Avoid JPEG for UI captures — quantization artifacts
  show up in text.
- Keep each file under **800 KB** after compression. Large uncompressed
  captures should be processed with `pngquant` (see below) or
  ImageOptim before committing.

## Helper script

`scripts/optimize-screenshots.py` validates the conventions above and,
when `pngquant` is available, compresses oversized images in place.

```bash
# Verify only (exit code 1 on any violation)
python3 scripts/optimize-screenshots.py --check

# Verify + compress with pngquant (if installed)
python3 scripts/optimize-screenshots.py --compress
```

Consider wiring `--check` into CI so stray large PNGs never land on
`master`.
