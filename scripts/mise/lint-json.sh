#!/usr/bin/env bash
set -euo pipefail

find . \
  \( -path ./.venv -o -path ./node_modules -o -path ./build -o -path ./dist -o -path ./.claude -o -path ./.codex -o -path ./.cursor -o -path ./.gemini \) -prune \
  -o -name '*.json' -print \
  | while IFS= read -r file; do
    mise exec -- jaq empty "${file}"
  done
