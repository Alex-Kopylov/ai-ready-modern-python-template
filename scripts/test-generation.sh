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

for agent_hook_config in .claude/settings.json .codex/hooks.json; do
  [[ -f "$agent_hook_config" ]] ||
    fail "missing default agent hook config: $agent_hook_config"
  jaq empty "$agent_hook_config" ||
    fail "invalid generated JSON: $agent_hook_config"
done
for agent_hook_script in scripts/agent-lint-fast.sh scripts/agent-stop-notify.sh; do
  [[ -x "$agent_hook_script" ]] ||
    fail "missing executable default agent hook script: $agent_hook_script"
done

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

mise exec -- taplo fmt --check
sed 's/^dependencies = \[\]$/dependencies=[]/' \
  pyproject.toml > pyproject.toml.tmp
mv pyproject.toml.tmp pyproject.toml
grep -Fxq 'dependencies=[]' pyproject.toml || {
  fail "expected an unformatted TOML fixture in pyproject.toml"
}
mise run format
grep -Fxq 'dependencies = []' pyproject.toml || {
  fail "mise run format did not format pyproject.toml"
}
git diff --quiet || {
  fail "mise run format changed the committed generated project"
}

mise exec -- uv run python -c "import my_project"
mise exec -- uv build --out-dir "${tmp_dir}/dist"

mkdir -p nested/agent-hook-probe
(
  cd nested/agent-hook-probe
  ../../scripts/agent-lint-fast.sh
) || fail "post-edit hook did not run lint-fast from a generated-project subdirectory"
rm -rf nested

cp src/my_project/main.py "${tmp_dir}/main.py.agent-hook-backup"
printf 'def broken(:\n' > src/my_project/main.py
agent_hook_failure_output="${tmp_dir}/agent-hook-failure.txt"
set +e
scripts/agent-lint-fast.sh >"${tmp_dir}/agent-hook-failure.stdout" \
  2>"$agent_hook_failure_output"
agent_hook_failure_status=$?
set -e
cp "${tmp_dir}/main.py.agent-hook-backup" src/my_project/main.py
[[ "$agent_hook_failure_status" -eq 2 ]] ||
  fail "post-edit hook returned ${agent_hook_failure_status}, expected 2"
grep -Fq 'mise run lint-fast failed' "$agent_hook_failure_output" ||
  fail "post-edit hook did not report lint failure on stderr"

claude_stop_hook_stdout="${tmp_dir}/agent-stop-notify-claude.stdout"
printf '{}\n' |
  scripts/agent-stop-notify.sh claude >"$claude_stop_hook_stdout"
jaq -e '.terminalSequence == "\u0007"' "$claude_stop_hook_stdout" >/dev/null ||
  fail "Claude stop hook did not return the supported bell terminalSequence"

codex_stop_hook_stdout="${tmp_dir}/agent-stop-notify-codex.stdout"
printf '{}\n' |
  scripts/agent-stop-notify.sh codex >"$codex_stop_hook_stdout"
jaq -e 'type == "object" and length == 0' "$codex_stop_hook_stdout" >/dev/null ||
  fail "Codex stop hook did not return an empty protocol object"

printf 'ok -- agent hooks run from subdirectories and report valid protocol results\n'

mise run lint

if [[ "$scenario" == github-actions-on ]]; then
  for workflow_extension in yml yaml; do
    workflow_probe=".github/workflows/zizmor-probe.${workflow_extension}"
    probe_output="${tmp_dir}/zizmor-probe-${workflow_extension}.txt"
    # shellcheck disable=SC2016  # GitHub expression must remain literal.
    printf '%s\n' \
      'name: Zizmor probe' \
      'on: issues' \
      'jobs:' \
      '  probe:' \
      '    runs-on: ubuntu-latest' \
      '    steps:' \
      '      - run: echo "${{ github.event.issue.title }}"' \
      > "$workflow_probe"
    if mise run lint-gha-security > "$probe_output" 2>&1; then
      fail "lint-gha-security did not scan .${workflow_extension} workflows"
    fi
    grep -Fq -- 'error[template-injection]' "$probe_output" ||
      fail "lint-gha-security failed without the expected template-injection"
    grep -Fq -- "$workflow_probe" "$probe_output" ||
      fail "lint-gha-security output did not name ${workflow_probe}"
    rm "$workflow_probe"
  done
  mise run lint-gha-security ||
    fail "lint-gha-security must pass after removing workflow probes"
fi

mise run lint-shell ||
  fail "lint-shell must succeed with the baseline shell script present"
printf '\nls $HOME\n' >> scripts/example.sh
if mise run lint-shell; then
  fail "lint-shell must reject a deliberate ShellCheck violation"
fi
git checkout -- scripts/example.sh
rm scripts/example.sh
mise run lint-shell ||
  fail "lint-shell must succeed when no shell scripts exist"
git checkout -- scripts/example.sh
# Scope the residue check to the probe target. The tree already carries
# unrelated churn at this point (uv.lock, .venv) from the earlier install steps,
# so a whole-tree `git status` check would be a false positive.
[[ -x scripts/example.sh ]] ||
  fail "lint-shell probes did not restore an executable scripts/example.sh"
git diff --quiet -- scripts/example.sh ||
  fail "lint-shell probes did not restore scripts/example.sh"

printf '#bad heading\n\n\n\nx\n' > EXTRA.md
if mise run lint-md; then
  fail "markdownlint accepted non-conforming root EXTRA.md"
fi
rm EXTRA.md

mkdir -p .claude
printf '#bad heading\n\n\n\nx\n' > .claude/probe.md
mise run lint-md ||
  fail "markdownlint did not ignore .claude/probe.md"
rm .claude/probe.md

agents_backup="${tmp_dir}/AGENTS.md.probe-backup"
cp AGENTS.md "$agents_backup"
printf '#bad heading\n\n\n\nx\n' > AGENTS.md
mise run lint-md ||
  fail "markdownlint did not ignore root AGENTS.md"
cp "$agents_backup" AGENTS.md

mkdir -p docs/specs
printf '#bad heading\n\n\n\nx\n' > docs/specs/probe.md
if mise run lint-md; then
  fail "markdownlint accepted non-conforming docs/specs/probe.md"
fi
rm -rf docs/specs

# Scope the residue check to the probe artefacts. The tree already carries
# unrelated churn at this point (uv.lock, .venv) from the earlier install steps,
# so a whole-tree `git status` check would be a false positive.
for probe in EXTRA.md .claude/probe.md docs/specs; do
  [[ ! -e "$probe" ]] ||
    fail "markdownlint probe left ${probe} behind in the generated project"
done
git diff --quiet -- AGENTS.md ||
  fail "markdownlint probe did not restore AGENTS.md"
git diff --quiet -- .claude/settings.json .codex/hooks.json ||
  fail "markdownlint probe changed the rendered agent hook configs"

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
