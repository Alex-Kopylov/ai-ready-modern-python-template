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

fail() {
  printf 'Generation assertion failed: %s\n' "$1" >&2
  exit 1
}

assert_file_present() {
  [[ -f "$1" ]] || fail "expected file: $1"
}

assert_file_absent() {
  [[ ! -e "$1" ]] || fail "unexpected file: $1"
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    fail "unexpected '$2' in $1"
  fi
}

printf 'Generating project with answers: %s\n' "$answers_file"
# --vcs-ref=HEAD selects the current local revision instead of Copier's
# default latest-tag resolution; Copier also snapshots dirty local changes.
uvx copier copy --defaults --vcs-ref=HEAD --data-file "$answers_file" "$repo_root" "$generated_dir"

case "$(basename "$answers_file")" in
  answers-defaults.yml | answers-everything-on.yml)
    assert_file_present "${generated_dir}/LICENSE"
    assert_contains "${generated_dir}/pyproject.toml" 'license = "MIT"'
    ;;
  answers-everything-off.yml)
    assert_file_absent "${generated_dir}/LICENSE"
    assert_file_present "${generated_dir}/pyproject.toml"
    assert_not_contains "${generated_dir}/pyproject.toml" "license ="
    ;;
  answers-github-actions-no-docker.yml)
    assert_file_absent "${generated_dir}/LICENSE"
    assert_contains "${generated_dir}/pyproject.toml" 'license = "LicenseRef-Proprietary"'
    assert_file_present "${generated_dir}/.github/dependabot.yml"
    assert_not_contains "${generated_dir}/.github/dependabot.yml" 'package-ecosystem: "docker"'
    ;;
esac

cd "$generated_dir"

git init
git config user.name "Template Generation Test"
git config user.email "template-generation@example.invalid"
git add .
git commit -m "chore: initial generated project"

mise trust --yes
mise install
mise run install
mise run lint
mise run test
# Generated-project CI runs test-cov; gate it here so the coverage
# fail-under path is exercised for every answer set.
mise run test-cov
