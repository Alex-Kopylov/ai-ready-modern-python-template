#!/usr/bin/env bash
set -euo pipefail

mapfile -t files < <(
  find . \
    \( -path ./.venv -o -path ./node_modules -o -path ./build -o -path ./dist -o -path ./.claude -o -path ./.codex -o -path ./.cursor -o -path ./.gemini \) -prune \
    -o -type f -name '*.sh' -print \
    || true
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No shell scripts to lint"
  exit 0
fi

for file in "${files[@]}"; do
  mise exec -- shellcheck "${file}"
done
