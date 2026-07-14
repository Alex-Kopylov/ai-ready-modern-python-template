#!/usr/bin/env bash
# Baseline script: keeps the ShellCheck toolchain exercised against a real
# target; replace with project scripts as they appear.
set -euo pipefail

main() {
  printf 'Hello from %s!\n' "${0##*/}"
}

main "$@"
