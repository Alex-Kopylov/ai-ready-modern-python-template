# ai-ready-modern-python-template

Copier template for universal, installable, framework-neutral Python projects.
Every generated project includes `uv`, `mise`, strict lint gates, tests, hooks,
Hatchling packaging, and a Docker baseline. GitHub automation is optional as one
complete bundle.

## Generate a Project

```bash
uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template my-project
```

Copier resolves the latest stable Git tag by default. Use a local checkout or
pass an explicit VCS ref only when testing unreleased template changes.

## Wizard

The wizard keeps project-shape choices small and explicit:

| Question | Default | Purpose |
| --- | --- | --- |
| `project_name` | `my_project` | Project, distribution, and Python package name |
| `project_description` | `Project description` | README and package metadata |
| `python_version` | `3.14` | Python, uv, Ruff, ty, and Docker |
| `license` | `MIT` | MIT, Proprietary, or Skip |
| `author_name` | empty | License owner and optional Docker maintainer |
| `use_github_actions` | `true` | Entire GitHub automation bundle |
| `extra_linters` | all | jscpd, typos, and markdownlint |
| `coverage_fail_under` | `80` | Coverage threshold; `0` disables the gate |

The same `project_name` is used for display text, distribution metadata, and
the Python import package. Choose a valid Python package name such as
`my_project`; naming mistakes surface when the generated project is installed,
imported, or linted.

Generated projects intentionally choose no application framework or runtime
entrypoint. Add the framework, dependencies, and launch command that fit the
actual product.

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
uv build
```

Generated projects intentionally start without `uv.lock`. The first
`mise run install`, `uv sync`, or `uv lock` creates it; commit `uv.lock` after
that first sync. `mise install` installs the pinned cross-language CLI tools;
uv is the sole Python provisioner and installs the `.python-version` selection
when the project is first synced.

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

Run the focused render contracts and both named end-to-end gates before opening
a PR:

```bash
scripts/test-render-contracts.sh
scripts/test-generation.sh github-actions-on
scripts/test-generation.sh github-actions-off
```

The render contracts cover targeted wizard overrides without installing tools.
The two generation scenarios install and import the project, build its wheel,
and run the full lint, test, and coverage gates.
