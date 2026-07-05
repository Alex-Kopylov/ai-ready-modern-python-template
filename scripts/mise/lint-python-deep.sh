#!/usr/bin/env bash
set -euo pipefail

mapfile -t src_python_files < <(find src -type f -name '*.py' || true)
if [[ ${#src_python_files[@]} -eq 0 ]]; then
  echo "No src Python files for whole-project analysis"
  exit 0
fi

uv run ty check src
uv run vulture --config .vulture.toml
