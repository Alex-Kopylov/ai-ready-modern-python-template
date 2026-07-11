# Repository Instructions

## Project Context

This repository is the `ai-ready-modern-python-template` Copier template.
Root files define the template itself; generated-project files live under
`template/` and are rendered through `copier.yml`.

Keep this repository focused on the reusable template. Do not adopt the
template into downstream projects from this worktree unless that is explicitly
requested as a separate task.

## Commands

- `scripts/test-render-contracts.sh`: run fast render-only wizard and output
  contracts.
- `scripts/test-generation.sh github-actions-on`: generate and gate the true
  wizard-default project.
- `scripts/test-generation.sh github-actions-off`: generate and gate the same
  defaults with only GitHub automation disabled.
- `scripts/test-generation.sh github-actions-off 3.11.9`: run the full
  exact-patch fixture; the optional version argument is reusable for Python
  coverage scenarios.

Inside a generated project, the standard commands are:

- `mise install`: install mise-managed CLI tools; Python is provisioned by uv.
- `mise run install`: install the current package and its dependencies.
- `mise run lint-fast`: run edit-safe lint targets for active development.
- `mise run lint`: run the full lint gate used by CI.
- `mise run lint-full`: explicit name for the full lint gate.
- `mise run format`: apply Ruff formatting and autofixes for `src`.
- `mise run test`: run the pytest suite under `tests`.
- `mise run test-cov`: run the pytest suite with a coverage report.
- `mise run install-hooks`: install prek-managed pre-commit and pre-push hooks.
- `uv build`: build the installable distribution with Hatchling.

## Tooling

- Use `jaq` instead of `jq` for JSON command-line work.
- Python provisioning, dependency management, and command execution in
  generated projects goes through `uv`; `.python-version` is the interpreter
  source of truth.
- Project task orchestration and native CLI tooling in generated projects go
  through `mise.toml`.
- The root repository intentionally does not keep generated-project
  `pyproject.toml`, `mise.toml`, `uv.lock`, `src/`, or Python tests.

## Template Invariants

- Every generated project is installable and buildable through Hatchling.
- Docker, `.dockerignore`, Hadolint configuration, task, and hook are baseline.
- `use_github_actions` is the only structural switch and controls the complete
  GitHub workflow, dependency automation, schema, and security bundle.
- `project_name` is used unchanged for the distribution and import package.
- The starter project and Docker command remain framework-neutral.

## Workflow

- Read `docs/superpowers/specs/2026-07-07-copier-template-design.md` before
  changing the template design.
- Keep coarse choices in `copier.yml`; keep fine-grained lint and tool tuning in
  generated files under `template/`.
- Do not make lint or test tasks silently pass when configured paths are
  missing; restore the path or update the configuration instead.
- Generated projects intentionally create `uv.lock` on first sync. Do not add a
  root template `uv.lock`.
- Use Copier filename conditions only for genuinely optional files, with
  `.jinja` outside the condition when file content is rendered.
- Temporary ad hoc tests are fine while developing or debugging. Remove them
  before committing; keep only tests that verify actual generated-project
  behavior.

## Releasing

Use the `dev-workflow:version-bumper` skill for every version change. Follow
its discovery and verification workflow instead of editing version strings by
hand.

After the release change is merged and CI is green, push the corresponding
`vX.Y.Z` tag, publish a GitHub Release, and smoke-test
`uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template my-project` so
the default Copier command resolves to the new stable version.
