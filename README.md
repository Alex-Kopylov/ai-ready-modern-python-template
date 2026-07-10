# ai-ready-modern-python-template

Copier template for AI-ready modern Python projects. It generates a small
starter project with `uv`, `mise`, strict lint gates, tests, hooks, and optional
Docker and GitHub Actions wiring.

## Generate a Project

```bash
uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template my-project
```

Copier resolves the latest Git tag by default. Until the first stable release
is tagged, use a local checkout or pass an explicit VCS ref.

## Wizard Modes

- Quick mode asks for the project name, package name, description, and setup
  mode, then applies the recommended defaults: Python 3.14, MIT license,
  Docker, GitHub Actions, and all optional linters.
- Custom mode adds coarse feature choices for the Python version (any 3.10+,
  default 3.14; minor like `3.13` or exact patch like `3.13.2`), license (MIT,
  Proprietary, or Skip to define it later without generating a `LICENSE` file),
  package build metadata, Docker, GitHub Actions, optional lint families, and
  coverage fail-under.

Fine-grained tuning stays in generated files. Edit `mise.toml`, `pyproject.toml`,
lint configs, hooks, or CI after generation instead of expanding the wizard for
every possible rule.

## After Generation

```bash
cd my-project
git init
git add .
git commit -m "chore: initial project from template"
mise install
mise run install
mise run install-hooks
mise run lint
mise run test
```

Generated projects intentionally start without `uv.lock`. The first
`mise run install`, `uv sync`, or `uv lock` creates it; commit `uv.lock` after
that first sync.

## Updating a Generated Project

From the generated project:

```bash
uvx copier update
```

Review the diff before committing. Copier uses `.copier-answers.yml` to replay
the original answers and merge template changes.

## Adopting an Existing Project

From the existing project root:

```bash
uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template .
git diff
```

Resolve conflicts deliberately. Keep domain-specific source, dependencies, and
runtime files where they are intentional; adopt the template's tooling and
quality-gate conventions where they fit.

## Template Development

Use the local generation matrix before opening a PR:

```bash
scripts/test-generation.sh scripts/answers-defaults.yml
scripts/test-generation.sh scripts/answers-everything-off.yml
scripts/test-generation.sh scripts/answers-everything-on.yml
scripts/test-generation.sh scripts/answers-github-actions-no-docker.yml
```

Root CI runs template linting plus the same four generated-project gates.
