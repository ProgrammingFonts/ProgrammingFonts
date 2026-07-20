#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_CONFIG="$ROOT/Sources/RootFontApp/Resources/AppVersion.json"

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/release-app.sh <git-tag>"
  echo "Example: bash scripts/release-app.sh v0.3.0-alpha"
  exit 1
fi

TAG="$1"
SHORT_VERSION="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["shortVersion"])' "$VERSION_CONFIG")"

if [[ "$TAG" != "v$SHORT_VERSION" && "$TAG" != "$SHORT_VERSION" ]]; then
  echo "Warning: tag '$TAG' does not match AppVersion shortVersion '$SHORT_VERSION'"
fi

cd "$ROOT"
bash scripts/build-app.sh

echo
echo "Release bundle ready at: $ROOT/.build/app/rootfont.app"
echo "Optional signing: export CODESIGN_IDENTITY=\"Developer ID Application: ...\" && bash scripts/build-app.sh"
echo "Create tag when ready: git tag -a '$TAG' -m 'Release $TAG'"
