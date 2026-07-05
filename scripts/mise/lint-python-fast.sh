#!/usr/bin/env bash
set -euo pipefail

python_dirs=(src)
if [[ -d tests ]]; then
  python_dirs+=(tests)
fi

mapfile -t python_files < <(find "${python_dirs[@]}" -type f -name '*.py' || true)
if [[ ${#python_files[@]} -eq 0 ]]; then
  echo "No Python files to lint"
  exit 0
fi

uv run ruff check "${python_files[@]}"
uv run ruff format --check "${python_files[@]}"

mapfile -t src_python_files < <(find src -type f -name '*.py' || true)
if [[ ${#src_python_files[@]} -eq 0 ]]; then
  echo "No src Python files for flake8"
  exit 0
fi

uv run flake8 "${src_python_files[@]}"
