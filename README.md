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
| `main_branch_name` | `main` | Git setup guidance and generated CI push branch |
| `python_version` | `3.14` | Python, uv, Ruff, ty, and Docker |
| `license` | `MIT` | MIT, Proprietary, or Skip |
| `author_name` | empty | License owner and optional Docker maintainer |
| `use_github_actions` | `true` | Entire GitHub automation bundle |
| `extra_linters` | all | jscpd, typos, and markdownlint |
| `parallel_testing` | `true` | Run pytest in parallel with pytest-xdist |
| `coverage_fail_under` | `80` | Coverage threshold; `0` disables the gate |

The same `project_name` is used for display text, distribution metadata, and
the Python import package. It must start with an ASCII letter, contain only
ASCII letters, digits, and internal underscores, and end with an ASCII letter
or digit. The wizard also rejects Python hard keywords but accepts soft
keywords that satisfy the unified name shape, such as `match` and `type`;
names such as `my_project` and `Acme_Project` remain valid.

`main_branch_name` is stored with the other Copier answers and controls the
post-copy `git init -b` guidance plus the generated CI push filter. Copier
updates render files but never initialize, rename, or reconfigure the existing
Git repository.

Minor Python answers from 3.10 through 3.14 map to fresh managed patches
verified with the template-pinned uv release. Exact patch answers are expert
mode and pass through unchanged: if uv cannot provide that managed build on the
current platform, choose another exact patch or a supported minor. The template
does not silently fall back to a system interpreter or source build.

Generated projects intentionally choose no application framework or runtime
entrypoint. Add the framework, dependencies, and launch command that fit the
actual product.

Fine-grained tuning stays in generated files. Edit `mise.toml`, `pyproject.toml`,
lint configs, hooks, or CI after generation instead of expanding the wizard for
every possible rule.

## After Generation

```bash
cd my-project
git init -b main
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
scripts/test-generation.sh github-actions-off 3.11.9
```

The render contracts cover targeted wizard overrides without installing tools.
The generation scenarios install and import the project, build its wheel, and
run the full lint, test, coverage, and installed-hook gates. The optional second
argument supplies a Python minor or exact patch for reusable version coverage.

Root CI runs six explicit full-generation rows: both GitHub-automation profiles
at the default Python 3.14, the Python 3.11.9 exact fixture, and minor inputs for
3.10, 3.12, and 3.13. This covers every supported minor while preserving both
default feature profiles. For matrix-only changes, run one representative new
row locally; clean GitHub runners execute the complete matrix.
