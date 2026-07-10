#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <github-actions-on|github-actions-off>\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

scenario="$1"
copier_args=()
case "$scenario" in
  github-actions-on)
    ;;
  github-actions-off)
    copier_args+=(--data use_github_actions=false)
    ;;
  *)
    usage
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

assert_path_absent() {
  [[ ! -e "$1" ]] || fail "unexpected path: $1"
}

assert_contains() {
  grep -Fq -- "$2" "$1" || fail "expected '$2' in $1"
}

assert_not_contains() {
  if grep -Fq -- "$2" "$1"; then
    fail "unexpected '$2' in $1"
  fi
}

assert_matches() {
  grep -Eq -- "$2" "$1" || fail "expected pattern '$2' in $1"
}

assert_not_matches() {
  if grep -Eq -- "$2" "$1"; then
    fail "unexpected pattern '$2' in $1"
  fi
}

printf 'Generating scenario: %s\n' "$scenario"
# --vcs-ref=HEAD selects the current local revision instead of Copier's
# default latest-tag resolution; Copier also snapshots dirty local changes.
uvx copier copy \
  --defaults \
  --vcs-ref=HEAD \
  "${copier_args[@]}" \
  "$repo_root" \
  "$generated_dir"

for docker_file in Dockerfile .dockerignore .hadolint.yaml; do
  assert_file_present "${generated_dir}/${docker_file}"
done
assert_contains "${generated_dir}/README.md" '## Docker'
assert_contains "${generated_dir}/mise.toml" '"aqua:hadolint/hadolint"'
assert_contains "${generated_dir}/mise.toml" '[tasks.lint-dockerfile]'
assert_contains "${generated_dir}/.pre-commit-config.yaml" '      - id: hadolint'

assert_matches "${generated_dir}/pyproject.toml" '^\[build-system\]$'
assert_not_matches \
  "${generated_dir}/pyproject.toml" \
  '^\[tool\.hatch\.build\.targets\.wheel\]$'
assert_not_matches "${generated_dir}/.pytest.ini" '^[[:space:]]*pythonpath[[:space:]]='
assert_contains "${generated_dir}/mise.toml" 'run = "uv sync --all-extras"'

case "$scenario" in
  github-actions-on)
    for automation_file in \
      .github/workflows/ci.yml \
      .github/dependabot.yml \
      .github/zizmor.yml \
      renovate.json5; do
      assert_file_present "${generated_dir}/${automation_file}"
    done
    assert_contains "${generated_dir}/pyproject.toml" '"check-jsonschema"'
    assert_contains "${generated_dir}/mise.toml" '"aqua:rhysd/actionlint"'
    assert_contains "${generated_dir}/mise.toml" '"aqua:zizmorcore/zizmor"'
    assert_contains "${generated_dir}/mise.toml" '[tasks.lint-github-actions]'
    assert_contains "${generated_dir}/mise.toml" '[tasks.lint-gha-security]'
    assert_contains \
      "${generated_dir}/.pre-commit-config.yaml" \
      '      - id: check-jsonschema-github-workflows'
    assert_contains "${generated_dir}/.pre-commit-config.yaml" '      - id: actionlint'
    assert_contains "${generated_dir}/.pre-commit-config.yaml" '      - id: zizmor'
    assert_contains \
      "${generated_dir}/.github/dependabot.yml" \
      'package-ecosystem: "docker"'
    ;;
  github-actions-off)
    assert_path_absent "${generated_dir}/.github"
    assert_path_absent "${generated_dir}/renovate.json5"
    assert_not_contains "${generated_dir}/pyproject.toml" "check-jsonschema"
    for automation_term in actionlint zizmor check-jsonschema; do
      assert_not_contains "${generated_dir}/mise.toml" "$automation_term"
      assert_not_contains "${generated_dir}/.pre-commit-config.yaml" "$automation_term"
    done
    assert_not_contains "${generated_dir}/README.md" '## CI'
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
mise exec -- uv run python -c "import my_project"
mise exec -- uv build --out-dir "${tmp_dir}/dist"
mise run lint
mise run test
mise run test-cov

printf 'ok -- scenario %s passed generation, build, and quality gates\n' "$scenario"
