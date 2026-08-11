#!/usr/bin/env bash
set -euo pipefail

tool_root=".build/rootfont-tools"
mkdir -p "$tool_root"

resolve_tool() {
  local name="$1"
  local version="$2"
  local url="$3"
  local installed
  installed="$(command -v "$name" || true)"
  if [[ -n "$installed" && "$($installed --version 2>/dev/null | head -n 1)" == *"$version"* ]]; then
    echo "$installed"
    return
  fi

  local binary="$tool_root/$name-$version"
  if [[ ! -x "$binary" ]]; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    curl --fail --silent --show-error --location "$url" --output "$temp_dir/tool.zip"
    unzip -q "$temp_dir/tool.zip" -d "$temp_dir/unpacked"
    local extracted
    extracted="$(find "$temp_dir/unpacked" -type f -name "$name" -perm -111 | head -n 1)"
    if [[ -z "$extracted" ]]; then
      echo "Unable to locate $name in downloaded artifact" >&2
      exit 1
    fi
    cp "$extracted" "$binary"
    chmod +x "$binary"
    rm -rf "$temp_dir"
  fi
  echo "$binary"
}

swiftformat="$(resolve_tool swiftformat 0.55.0 https://github.com/nicklockwood/SwiftFormat/releases/download/0.55.0/swiftformat.zip)"
swiftlint="$(resolve_tool swiftlint 0.65.0 https://github.com/realm/SwiftLint/releases/download/0.65.0/SwiftLintBinary.artifactbundle.zip)"

"$swiftformat" Sources Tests --lint --config .swiftformat
"$swiftlint" lint --config .swiftlint.yml --strict
