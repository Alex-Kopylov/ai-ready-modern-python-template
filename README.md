# ai-ready-modern-python-template

An AI-ready Python 3.14.6 project template for fast, low-friction,
high-confidence development.

This template is built for developers who use AI coding assistants and want the
project to catch low-quality changes early. It combines a pinned toolchain,
fast dependency management, strict linting, tests, hooks, secret scanning, and
GitHub Actions so generated code gets immediate feedback before it reaches
manual review.

The goal is simple: after the configured checks pass, manual review should be
focused on product intent and architecture instead of formatting, obvious bugs,
unsafe patterns, or missing quality gates. Ideally, generated changes should not
need mechanical cleanup once the linters and tests are green.

## What this template optimizes for

- Fast setup with `uv` and `mise`.
- Reproducible local and CI tooling.
- Early feedback for common AI-generated code issues.
- One aggregate lint command for local use and CI, plus explicit commit-time
  guardrails.
- Guardrails that reduce the need for constant human supervision.

## Check surfaces

- `mise run lint` is the default local and CI lint contract. Keep it stable,
  deterministic, and low-noise.
- `.pre-commit-config.yaml` owns commit-time guardrails. It can include
  additional checks that are useful before saving a commit but too
  context-sensitive for the default aggregate.
- `deptry` is intentionally commit-hook-only: dependency-declaration checks are
  useful at commit time, but can be noisy while an agent is still staging a
  broader dependency or deployment change.

## Quick start

```bash
mise install            # install pinned tools
mise run install        # install Python dependencies
mise run install-hooks  # install prek-managed pre-commit and pre-push hooks
mise run lint           # run all linters in parallel
mise run test           # run the pytest suite
```
