#!/usr/bin/env bash
set -euo pipefail

coverage=false
if [[ "${1:-}" == "--coverage" ]]; then
  coverage=true
  shift
fi

if [[ $# -ne 0 ]]; then
  echo "Unexpected arguments: $*" >&2
  exit 2
fi

if [[ ! -d tests ]]; then
  echo "No product tests to run"
  exit 0
fi

mapfile -t test_files < <(find tests -type f \( -name 'test_*.py' -o -name '*_test.py' \) || true)
if [[ ${#test_files[@]} -eq 0 ]]; then
  echo "No product tests to run"
  exit 0
fi

if [[ "${coverage}" == true ]]; then
  uv run pytest tests/ --cov --cov-report=term-missing
else
  uv run pytest tests/
fi
