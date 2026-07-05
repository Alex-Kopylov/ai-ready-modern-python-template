#!/usr/bin/env bash
set -euo pipefail

mapfile -t files < <(
  find . \
    \( -path ./.venv -o -path ./build -o -path ./dist -o -path ./.claude -o -path ./.codex -o -path ./.cursor -o -path ./.gemini \) -prune \
    -o \( -name 'Dockerfile' -o -name 'Dockerfile.*' -o -name '*.dockerfile' \) -print \
    || true
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No Dockerfiles to lint"
  exit 0
fi

for file in "${files[@]}"; do
  mise exec -- hadolint "${file}"
done
