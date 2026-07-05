#!/usr/bin/env bash
set -euo pipefail

mapfile -t files < <(
  find . \
    \( -path ./.venv -o -path ./node_modules -o -path ./build -o -path ./dist -o -path ./.claude -o -path ./.codex -o -path ./.cursor -o -path ./.gemini \) -prune \
    -o -name '*.toml' -print \
    || true
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No TOML files to lint"
  exit 0
fi

mise exec -- taplo lint "${files[@]}"
