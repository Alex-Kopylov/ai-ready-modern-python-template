#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
render_log="${tmp_dir}/render.log"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fail() {
  printf 'Render contract failed: %s\n' "$1" >&2
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

assert_occurrences() {
  local actual
  actual="$(grep -Fc -- "$2" "$1" || true)"
  [[ "$actual" -eq "$3" ]] || \
    fail "expected '$2' exactly $3 times in $1; found $actual"
}

render_project() {
  local destination="$1"
  shift

  if ! uvx copier copy \
    --quiet \
    --defaults \
    --vcs-ref=HEAD \
    "$@" \
    "$repo_root" \
    "$destination" 2>"$render_log"; then
    sed -n '1,160p' "$render_log" >&2
    fail "Copier could not render $destination"
  fi
}

obsolete_questions='setup''_mode|use''_docker|is''_package'
assert_not_matches "${repo_root}/copier.yml" "^(${obsolete_questions}):"
assert_not_contains "${repo_root}/copier.yml" "setup""_mode == 'custom'"

question_map="$({
  awk '
    function emit_question() {
      if (question != "") {
        print (hidden ? "hidden:" : "visible:") question
      }
    }

    /^[a-z][a-z0-9_]*:$/ {
      emit_question()
      question = substr($0, 1, length($0) - 1)
      hidden = 0
      next
    }

    question != "" && /^  when: false$/ { hidden = 1 }

    END { emit_question() }
  ' "${repo_root}/copier.yml"
})"
expected_question_map="$(printf '%s\n' \
  visible:project_name \
  visible:project_description \
  visible:python_version \
  visible:license \
  visible:author_name \
  visible:use_github_actions \
  visible:extra_linters \
  visible:coverage_fail_under \
  hidden:python_version_minor \
  hidden:python_version_pin)"
[[ "$question_map" == "$expected_question_map" ]] || {
  printf 'Expected question map:\n%s\nActual question map:\n%s\n' \
    "$expected_question_map" \
    "$question_map" >&2
  fail "copier.yml question visibility changed"
}

printf 'ok -- wizard exposes only the supported choices\n'

default_dir="${tmp_dir}/default"
render_project "$default_dir"

assert_matches "${default_dir}/pyproject.toml" '^\[build-system\]$'
assert_not_matches \
  "${default_dir}/pyproject.toml" \
  '^\[tool\.hatch\.build\.targets\.wheel\]$'
assert_not_matches "${default_dir}/.pytest.ini" '^[[:space:]]*pythonpath[[:space:]]='
assert_contains \
  "${default_dir}/pyproject.toml" \
  'python-preference = "only-managed"'
assert_not_matches \
  "${default_dir}/mise.toml" \
  '^[[:space:]]*python[[:space:]]*='
assert_file_present "${default_dir}/src/my_project/__init__.py"
assert_file_present "${default_dir}/LICENSE"
assert_contains "${default_dir}/LICENSE" 'Copyright (c) 2026 my_project'
assert_not_contains "${default_dir}/Dockerfile" 'LABEL maintainer='
assert_not_contains "${default_dir}/pyproject.toml" "fastapi"
assert_not_contains "${default_dir}/pyproject.toml" "uvicorn"
assert_not_contains "${default_dir}/Dockerfile" "fastapi"
assert_not_contains "${default_dir}/Dockerfile" "uvicorn"

printf 'ok -- default project is installable and framework-neutral\n'

for docker_file in Dockerfile .dockerignore .hadolint.yaml; do
  assert_file_present "${default_dir}/${docker_file}"
done
assert_contains \
  "${default_dir}/Dockerfile" \
  'FROM ghcr.io/astral-sh/uv:0.11.25-trixie-slim'
assert_not_contains "${default_dir}/Dockerfile" '0.11.25-python'
assert_contains \
  "${default_dir}/Dockerfile" \
  'source=.python-version,target=.python-version'
assert_contains "${default_dir}/Dockerfile" 'uv python install &&'
assert_contains "${default_dir}/mise.toml" '"aqua:hadolint/hadolint"'
assert_contains "${default_dir}/mise.toml" '[tasks.lint-dockerfile]'
assert_contains "${default_dir}/.pre-commit-config.yaml" '      - id: hadolint'
assert_contains "${default_dir}/README.md" '## Docker'

printf 'ok -- Docker and Hadolint are part of every default render\n'

for automation_file in \
  .github/workflows/ci.yml \
  .github/dependabot.yml \
  .github/zizmor.yml \
  renovate.json5; do
  assert_file_present "${default_dir}/${automation_file}"
done
assert_contains "${default_dir}/pyproject.toml" '"check-jsonschema"'
assert_contains "${default_dir}/mise.toml" '"aqua:rhysd/actionlint"'
assert_contains "${default_dir}/mise.toml" '"aqua:zizmorcore/zizmor"'
assert_contains "${default_dir}/mise.toml" '[tasks.lint-github-actions]'
assert_contains "${default_dir}/mise.toml" '[tasks.lint-gha-security]'
assert_contains "${default_dir}/.pre-commit-config.yaml" '      - id: actionlint'
assert_contains "${default_dir}/.pre-commit-config.yaml" '      - id: zizmor'
assert_contains "${default_dir}/.github/dependabot.yml" 'package-ecosystem: "docker"'
assert_occurrences \
  "${default_dir}/.github/workflows/ci.yml" \
  'cache-python: true' \
  2
assert_occurrences \
  "${default_dir}/.github/workflows/ci.yml" \
  '- run: uv python install' \
  2

printf 'ok -- GitHub automation defaults on as one complete bundle\n'

github_off_dir="${tmp_dir}/github-actions-off"
render_project "$github_off_dir" --data use_github_actions=false

assert_path_absent "${github_off_dir}/.github"
assert_path_absent "${github_off_dir}/renovate.json5"
assert_file_present "${github_off_dir}/Dockerfile"
assert_file_present "${github_off_dir}/.hadolint.yaml"
assert_not_contains "${github_off_dir}/pyproject.toml" "check-jsonschema"
for automation_term in actionlint zizmor check-jsonschema; do
  assert_not_contains "${github_off_dir}/mise.toml" "$automation_term"
  assert_not_contains "${github_off_dir}/.pre-commit-config.yaml" "$automation_term"
done
assert_not_contains "${github_off_dir}/README.md" '## CI'
assert_not_contains "${github_off_dir}/.dockerignore" '.github/'
assert_not_contains "${github_off_dir}/.markdownlint-cli2.jsonc" '.github/'
assert_not_contains "${github_off_dir}/docs/lint-strategy.md" 'GitHub Actions'
assert_not_contains "${github_off_dir}/docs/lint-strategy.md" 'workflow file'

printf 'ok -- GitHub automation switches off without disabling Docker\n'

proprietary_dir="${tmp_dir}/proprietary"
render_project "$proprietary_dir" --data license=Proprietary
assert_path_absent "${proprietary_dir}/LICENSE"
assert_contains \
  "${proprietary_dir}/pyproject.toml" \
  'license = "LicenseRef-Proprietary"'

skip_dir="${tmp_dir}/skip-license"
render_project "$skip_dir" --data license=Skip
assert_path_absent "${skip_dir}/LICENSE"
assert_not_matches "${skip_dir}/pyproject.toml" '^[[:space:]]*license[[:space:]]='

printf 'ok -- Proprietary and Skip license contracts render correctly\n'

author_dir="${tmp_dir}/named-author"
render_project "$author_dir" --data 'author_name=Ada Lovelace'
assert_contains "${author_dir}/LICENSE" 'Copyright (c) 2026 Ada Lovelace'
assert_contains "${author_dir}/Dockerfile" 'LABEL maintainer="Ada Lovelace"'

printf 'ok -- author metadata reaches MIT and Docker outputs\n'

python_310_dir="${tmp_dir}/python-3.10"
render_project "$python_310_dir" --data python_version=3.10
assert_contains "${python_310_dir}/pyproject.toml" 'requires-python = ">=3.10"'
assert_contains "${python_310_dir}/pyproject.toml" 'python-version = "3.10"'
assert_not_matches \
  "${python_310_dir}/mise.toml" \
  '^[[:space:]]*python[[:space:]]*='
assert_contains "${python_310_dir}/.python-version" '3.10'
assert_contains "${python_310_dir}/.ruff.toml" 'target-version = "py310"'
assert_not_contains "${python_310_dir}/Dockerfile" '0.11.25-python'

python_patch_dir="${tmp_dir}/python-3.13.2"
render_project "$python_patch_dir" --data python_version=3.13.2
assert_contains "${python_patch_dir}/pyproject.toml" 'requires-python = ">=3.13"'
assert_contains "${python_patch_dir}/pyproject.toml" 'python-version = "3.13"'
assert_not_matches \
  "${python_patch_dir}/mise.toml" \
  '^[[:space:]]*python[[:space:]]*='
assert_contains "${python_patch_dir}/.python-version" '3.13.2'
assert_contains "${python_patch_dir}/.ruff.toml" 'target-version = "py313"'
assert_not_contains "${python_patch_dir}/Dockerfile" '0.11.25-python'

printf 'ok -- minor and exact-patch Python versions reach every consumer\n'

coverage_off_dir="${tmp_dir}/coverage-off"
render_project "$coverage_off_dir" --data coverage_fail_under=0
assert_not_matches \
  "${coverage_off_dir}/pyproject.toml" \
  '^[[:space:]]*fail_under[[:space:]]='

printf 'ok -- zero disables the coverage gate\n'

no_linters_dir="${tmp_dir}/no-optional-linters"
render_project "$no_linters_dir" --data 'extra_linters=[]'
assert_path_absent "${no_linters_dir}/.jscpd.json"
assert_path_absent "${no_linters_dir}/.markdownlint.jsonc"
assert_path_absent "${no_linters_dir}/.markdownlint-cli2.jsonc"
for optional_term in \
  'node = ' \
  'npm:jscpd' \
  'npm:markdownlint-cli2' \
  'aqua:crate-ci/typos' \
  '[tasks.lint-md]' \
  '[tasks.lint-duplicates]' \
  '[tasks.lint-typos]'; do
  assert_not_contains "${no_linters_dir}/mise.toml" "$optional_term"
done
assert_not_contains "${no_linters_dir}/.pre-commit-config.yaml" '      - id: jscpd'
assert_not_contains "${no_linters_dir}/.pre-commit-config.yaml" '      - id: typos'

printf 'ok -- optional linter selection can be empty\n'

named_dir="${tmp_dir}/named-project"
render_project "$named_dir" --data project_name=Acme_Project
assert_file_present "${named_dir}/src/Acme_Project/__init__.py"
assert_file_present "${named_dir}/tests/unit/Acme_Project/test_main.py"
assert_contains \
  "${named_dir}/tests/unit/Acme_Project/test_main.py" \
  'from Acme_Project.main import main'
assert_contains "${named_dir}/pyproject.toml" 'name = "Acme_Project"'
assert_contains "${named_dir}/README.md" '# Acme_Project'
assert_contains "${named_dir}/README.md" 'docker build -t Acme_Project .'

printf 'ok -- one project name is used unchanged everywhere\n'

if rg -n --hidden --glob '!.git' "$obsolete_questions" "$repo_root"; then
  fail "obsolete wizard concepts remain in the repository"
fi

printf 'ok -- obsolete wizard concepts are absent repository-wide\n'
