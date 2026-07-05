#!/usr/bin/env bash
set -euo pipefail

python_dirs=(src)
if [[ -d tests ]]; then
  python_dirs+=(tests)
fi

mapfile -t python_files < <(find "${python_dirs[@]}" -type f -name '*.py' || true)
if [[ ${#python_files[@]} -eq 0 ]]; then
  echo "No Python files to format"
  exit 0
fi

uv run ruff format "${python_files[@]}"
uv run ruff check --fix "${python_files[@]}"
