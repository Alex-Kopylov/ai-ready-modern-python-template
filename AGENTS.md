# Repository Instructions

## Project Context

This repository is the `ai-ready-modern-python-template` Copier template.
Root files define the template itself; generated-project files live under
`template/` and are rendered through `copier.yml`.

Part 1 of the Copier migration keeps this repository focused on the reusable
template only. Do not adopt the template into downstream projects from this
worktree unless that is explicitly requested as a separate task.

## Commands

- `scripts/test-generation.sh tests/fixtures/answers-defaults.yml`: generate and gate
  the quick-mode default project.
- `scripts/test-generation.sh tests/fixtures/answers-everything-off.yml`: generate and
  gate the custom project with optional features disabled.
- `scripts/test-generation.sh tests/fixtures/answers-everything-on.yml`: generate and
  gate the custom project with optional features enabled.
- `scripts/test-generation.sh tests/fixtures/answers-github-actions-no-docker.yml`:
  generate and gate the mixed project with GitHub Actions enabled and Docker
  disabled.

Inside a generated project, the standard commands are:

- `mise install`: install mise-managed tools.
- `mise run install`: install Python project dependencies.
- `mise run lint-fast`: run edit-safe lint targets for active development.
- `mise run lint`: run the full lint gate used by CI.
- `mise run lint-full`: explicit name for the full lint gate.
- `mise run format`: apply Ruff formatting and autofixes for `src`.
- `mise run test`: run the pytest suite under `tests`.
- `mise run test-cov`: run the pytest suite with a coverage report.
- `mise run install-hooks`: install prek-managed pre-commit and pre-push hooks.

## Tooling

- Use `jaq` instead of `jq` for JSON command-line work.
- Python dependency and command execution in generated projects goes through
  `uv`.
- Project task orchestration and native CLI tooling in generated projects go
  through `mise.toml`.
- The root repository intentionally does not keep generated-project
  `pyproject.toml`, `mise.toml`, `uv.lock`, `src/`, or Python tests. Root
  `tests/fixtures/` contains only template-generation answer sets.

## Workflow

- Read `docs/superpowers/specs/2026-07-07-copier-template-design.md` before
  changing the template migration design.
- Keep coarse choices in `copier.yml`; keep fine-grained lint and tool tuning in
  generated files under `template/`.
- Do not make lint or test tasks silently pass when configured paths are
  missing; restore the path or update the configuration instead.
- Generated projects intentionally create `uv.lock` on first sync. Do not add a
  root template `uv.lock`.
- Use Copier filename conditions for optional files, with `.jinja` outside the
  condition when file content is rendered.
- Temporary ad hoc tests are fine while developing or debugging. Remove them
  before committing; keep only tests that verify actual generated-project
  behavior.

## Releasing

After the Copier migration PR is merged and CI is green, tag `v1.0.0` on the
merge commit so `uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template
my-project` resolves to the stable template version by default.
