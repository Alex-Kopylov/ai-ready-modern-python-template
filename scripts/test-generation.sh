#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <answers.yml>\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
answers_file="$1"
if [[ "$answers_file" != /* ]]; then
  answers_file="${repo_root}/${answers_file}"
fi

if [[ ! -f "$answers_file" ]]; then
  printf 'Answers file not found: %s\n' "$answers_file" >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
generated_dir="${tmp_dir}/generated-project"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

printf 'Generating project with answers: %s\n' "$answers_file"
# --vcs-ref=HEAD makes copier include uncommitted template changes; without
# it, local runs silently generate from the last commit and dirty edits go
# untested.
uvx copier copy --defaults --vcs-ref=HEAD --data-file "$answers_file" "$repo_root" "$generated_dir"

cd "$generated_dir"

git init
git config user.name "Template Generation Test"
git config user.email "template-generation@example.invalid"
git add .
git commit -m "chore: initial generated project"

mise trust --yes
mise install
uv sync
mise run lint
mise run test
# Generated-project CI runs test-cov; gate it here so the coverage
# fail-under path is exercised for every answer set.
mise run test-cov
