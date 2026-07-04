# Repository Instructions

## Project Context

This is a new repository template. The project purpose is not fixed yet, so
keep changes generic and avoid adding domain-specific assumptions until the
repo direction is clear.

## Commands

- `mise install`: install mise-managed tools.
- `mise run install`: install Python project dependencies.
- `mise run lint`: run configured lint targets in parallel.
- `mise run format`: apply Ruff formatting and autofixes for `src` and
  `tests`.
- `mise run test`: run the pytest suite under `tests`.
- `mise run test-cov`: run the pytest suite with a coverage report.
- `mise run install-hooks`: install prek-managed pre-commit and pre-push hooks.

## Tooling

- Use `jaq` instead of `jq` for JSON command-line work.
- Python dependency and command execution goes through `uv`.
- Project task orchestration and native CLI tooling go through `mise.toml`;
  run `mise install` before invoking native linters directly.
- Node-based lint CLIs are pinned in `mise.toml` through mise's npm backend
  and installed with `mise install`.
- Use `zizmor` to catch workflow security issues at commit time.

## Workflow

- Prefer the existing `mise run` tasks before invoking tools directly.
- Keep generated or project-specific automation out of shared config unless the
  supporting scripts are committed too.
