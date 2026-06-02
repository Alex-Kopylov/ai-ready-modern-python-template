# Repository Instructions

## Project Context

This is a new repository template. The project purpose is not fixed yet, so
keep changes generic and avoid adding domain-specific assumptions until the
repo direction is clear.

## Commands

- `mise install`: install mise-managed tools.
- `mise run install`: install Python and Node tool dependencies.
- `mise run lint`: run configured lint targets in parallel.
- `mise run format`: apply Ruff formatting and autofixes for `src` and
  `tests`.
- `mise run test`: run the pytest suite under `tests`.
- `mise run install-hooks`: install pre-commit and pre-push hooks.
- `make <target>` delegates to `mise run <target>` for compatibility.

## Tooling

- Use `jaq` instead of `jq` for JSON command-line work.
- Python dependency and command execution goes through `uv`.
- Project task orchestration and native CLI tooling go through `mise.toml`;
  run `mise install` before invoking native linters directly.
- Node-based lint tools are pinned in `package.json` and installed with
  `npm ci`.

## Workflow

- Prefer the existing `mise run` tasks before invoking tools directly.
- Keep generated or project-specific automation out of shared config unless the
  supporting scripts are committed too.
