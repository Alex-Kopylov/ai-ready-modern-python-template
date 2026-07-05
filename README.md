# ai-ready-modern-python-template

An AI-ready Python 3.14.6 project template for fast, low-friction,
high-confidence development.

This template is built for developers who use AI coding assistants and want the
project to catch low-quality changes early. It combines a pinned toolchain,
fast dependency management, strict checks, tests, hooks, secret scanning, and
GitHub Actions so generated code gets immediate feedback before it reaches
manual review.

The goal is simple: after the configured checks pass, manual review should be
focused on product intent and architecture instead of formatting, obvious bugs,
unsafe patterns, or missing quality gates. Ideally, generated changes should not
need mechanical cleanup once the checks and tests are green.

## What this template optimizes for

- Fast setup with `uv` and `mise`.
- Reproducible local and CI tooling.
- Early feedback for common AI-generated code issues.
- Documented quality gates for active editing and final validation.
- Guardrails that reduce the need for constant human supervision.

## Documentation

- [Lint strategy](docs/lint-strategy.md): lint command groups, commit hooks,
  and CI policy.
- [Other modern Python tools](docs/other-modern-python-tools.md): tools that
  may be useful when adapting this template to a concrete domain, package, or
  team workflow.

## Quick start

```bash
mise install            # install pinned tools
mise run install        # install Python dependencies
mise run install-hooks  # install prek-managed pre-commit and pre-push hooks
mise run lint           # run the full lint gate
mise run test           # run the pytest suite
```
