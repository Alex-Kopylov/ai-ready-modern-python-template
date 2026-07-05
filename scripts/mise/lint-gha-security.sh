#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d .github/workflows ]]; then
  echo "No GitHub Actions workflows to scan"
  exit 0
fi

mapfile -t files < <(find .github/workflows \( -name '*.yml' -o -name '*.yaml' \) -print || true)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No GitHub Actions workflow files to scan"
  exit 0
fi

mise exec -- zizmor "${files[@]}"
