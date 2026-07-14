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

printf 'Generating scenario: %s\n' "$scenario"
# --vcs-ref=HEAD selects the current local revision instead of Copier's
# default latest-tag resolution; Copier also snapshots dirty local changes.
uvx copier copy \
  --defaults \
  --vcs-ref=HEAD \
  "${copier_args[@]}" \
  "$repo_root" \
  "$generated_dir"

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
sed -i '$a# Installed-hook ShellCheck regression fixture.' scripts/example.sh
hook_files=(pyproject.toml src/my_project/main.py .copier-answers.yml scripts/example.sh)
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
