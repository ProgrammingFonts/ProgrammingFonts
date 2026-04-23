#!/bin/bash
# Install tracked Git hooks from scripts/hooks/ into .git/hooks/.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/scripts/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

mkdir -p "$HOOKS_DST"

for hook in pre-commit; do
    cp "$HOOKS_SRC/$hook" "$HOOKS_DST/$hook"
    chmod +x "$HOOKS_DST/$hook"
    echo "Installed: $HOOKS_DST/$hook"
done
