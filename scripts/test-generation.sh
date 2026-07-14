#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf \
    'Usage: %s <github-actions-on|github-actions-off> [python-version]\n' \
    "$0" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

scenario="$1"
python_version_input="${2:-}"
copier_args=()
if [[ -n "$python_version_input" ]]; then
  copier_args+=(--data "python_version=${python_version_input}")
fi
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

assert_python_request_matches_patch() {
  local request="$1"
  local resolved_patch="$2"
  local request_source="$3"

  if [[ "$request" =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
    [[ "$resolved_patch" == "$request" ]] ||
      fail \
        "${request_source} ${request} resolved to Python ${resolved_patch}"
  elif [[ "${resolved_patch%.*}" != "$request" ]]; then
    fail "${request_source} ${request} resolved to Python ${resolved_patch}"
  fi
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

assert_match_count() {
  local actual_count
  actual_count="$(grep -Ec -- "$2" "$1" || true)"
  [[ "$actual_count" -eq "$3" ]] ||
    fail "expected $3 matches for pattern '$2' in $1, found $actual_count"
}

assert_occurrences() {
  local actual
  actual="$(grep -Fc -- "$2" "$1" || true)"
  [[ "$actual" -eq "$3" ]] || \
    fail "expected '$2' exactly $3 times in $1; found $actual"
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
assert_contains \
  "${generated_dir}/Dockerfile" \
  'FROM ghcr.io/astral-sh/uv:0.11.25-trixie-slim'
assert_not_contains "${generated_dir}/Dockerfile" '0.11.25-python'
assert_contains \
  "${generated_dir}/Dockerfile" \
  'source=.python-version,target=.python-version'
assert_contains "${generated_dir}/Dockerfile" 'uv python install &&'
assert_contains "${generated_dir}/mise.toml" '"aqua:hadolint/hadolint"'
assert_contains "${generated_dir}/mise.toml" '[tasks.lint-dockerfile]'
assert_contains "${generated_dir}/.pre-commit-config.yaml" '      - id: hadolint'

assert_matches "${generated_dir}/pyproject.toml" '^\[build-system\]$'
assert_not_matches \
  "${generated_dir}/pyproject.toml" \
  '^\[tool\.hatch\.build\.targets\.wheel\]$'
assert_not_matches "${generated_dir}/.pytest.ini" '^[[:space:]]*pythonpath[[:space:]]='
assert_contains \
  "${generated_dir}/pyproject.toml" \
  'python-preference = "only-managed"'
assert_not_matches \
  "${generated_dir}/mise.toml" \
  '^[[:space:]]*python[[:space:]]*='
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
    assert_not_contains \
      "${generated_dir}/.github/workflows/ci.yml" \
      'astral-sh/setup-uv'
    assert_not_contains \
      "${generated_dir}/.github/workflows/ci.yml" \
      'uv python install'
    assert_not_contains \
      "${generated_dir}/.github/workflows/ci.yml" \
      'uv lock --check'
    assert_occurrences \
      "${generated_dir}/.github/workflows/ci.yml" \
      'uv sync --all-extras --locked' \
      2
    assert_occurrences \
      "${generated_dir}/.github/workflows/ci.yml" \
      'jdx/mise-action' \
      2
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

requested_python_version="$(
  sed -n 's/^python_version: //p' .copier-answers.yml | tr -d "'\""
)"
[[ -n "$requested_python_version" ]] || fail "missing python_version answer"
if [[ -n "$python_version_input" &&
      "$requested_python_version" != "$python_version_input" ]]; then
  fail \
    "python_version answer ${requested_python_version} != input ${python_version_input}"
fi
rendered_python_version="$(tr -d '[:space:]' < .python-version)"
[[ -n "$rendered_python_version" ]] || fail "empty .python-version"

main_branch_name="$(
  sed -n 's/^main_branch_name: //p' .copier-answers.yml | tr -d "'\""
)"
[[ -n "$main_branch_name" ]] || fail "missing main_branch_name answer"

git_home="${tmp_dir}/git-home"
mkdir -p "$git_home"
GIT_CONFIG_NOSYSTEM=1 HOME="$git_home" git init -b "$main_branch_name"
actual_branch_name="$(git symbolic-ref --short HEAD)"
[[ "$actual_branch_name" == "$main_branch_name" ]] || {
  fail "generated repo branch '$actual_branch_name' != '$main_branch_name'"
}
git config user.name "Template Generation Test"
git config user.email "template-generation@example.invalid"
git add .
git commit -m "chore: initial generated project"

mise trust --yes
mise install
mise_tools="$(mise ls --current --json)"
if grep -Eq '"python"' <<<"$mise_tools"; then
  fail "mise must not provision Python: $mise_tools"
fi

mise exec -- uv python install
uv_python_version="$(mise exec -- uv python find --show-version)"
if [[ ! "$uv_python_version" =~ ^3\.[0-9]+\.[0-9]+$ ]]; then
  fail "uv did not resolve a full Python patch: $uv_python_version"
fi
assert_python_request_matches_patch \
  "$requested_python_version" \
  "$uv_python_version" \
  "python_version answer"
assert_python_request_matches_patch \
  "$rendered_python_version" \
  "$uv_python_version" \
  ".python-version"

mise run install
venv_python_version="$(
  .venv/bin/python -c \
    'import platform; print(platform.python_version())'
)"
if [[ "$uv_python_version" != "$venv_python_version" ]]; then
  fail \
    "uv Python ${uv_python_version} != .venv Python ${venv_python_version}"
fi
printf \
  'ok -- uv and .venv use Python %s; mise provisions no Python\n' \
  "$uv_python_version"

mise exec -- uv run python -c "import my_project"
mise exec -- uv build --out-dir "${tmp_dir}/dist"
mise run lint
mise run test
mise run test-cov

mise run install-hooks
hook_path_dir="${tmp_dir}/hook-path"
mkdir -p "$hook_path_dir"
ln -s "$(command -v mise)" "${hook_path_dir}/mise"
hook_path="${hook_path_dir}:/usr/bin:/bin"

if ! env PATH="$hook_path" sh -c 'command -v mise >/dev/null'; then
  fail "expected mise on isolated hook PATH"
fi
if env PATH="$hook_path" sh -c 'command -v uv >/dev/null'; then
  fail "unexpected uv on isolated hook PATH"
fi

sed -i '$a# Installed-hook PATH regression fixture.' pyproject.toml
sed -i 's/Hello, world!/Hello, hook smoke!/' src/my_project/main.py
sed -i '$a# Installed-hook PATH regression fixture.' .copier-answers.yml
hook_files=(pyproject.toml src/my_project/main.py .copier-answers.yml)
if [[ -f .github/workflows/ci.yml ]]; then
  sed -i '$a# Installed-hook PATH regression fixture.' .github/workflows/ci.yml
  hook_files+=(.github/workflows/ci.yml)
fi
git add "${hook_files[@]}"
for hook_file in "${hook_files[@]}"; do
  if git diff --cached --quiet -- "$hook_file"; then
    fail "expected staged hook input: $hook_file"
  fi
done

env PATH="$hook_path" git commit -m "test: exercise installed hooks"

expected_uv_hook_count=8
if [[ "$scenario" == github-actions-on ]]; then
  expected_uv_hook_count=9
fi
assert_not_matches \
  .pre-commit-config.yaml \
  '^[[:space:]]*entry: uv( |$)'
assert_match_count \
  .pre-commit-config.yaml \
  '^[[:space:]]*entry: mise exec -- uv( |$)' \
  "$expected_uv_hook_count"

printf 'ok -- scenario %s passed generation, installed hooks, build, and quality gates\n' "$scenario"
