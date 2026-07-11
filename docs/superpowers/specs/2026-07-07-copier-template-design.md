# Copier-based template transformation — design spec

Date: 2026-07-07

Amended: 2026-07-11

Status: approved by user

## Goal

Transform `ai-ready-modern-python-template` into a Copier template for a
universal, installable Python project. The wizard owns a small set of clear
project choices. Every render includes packaging and Docker; a single switch
controls the complete GitHub automation bundle.

The generated starter is framework-neutral. It has no FastAPI, Uvicorn, or
other application-framework dependency, configuration, entrypoint, or Docker
launch command. Ruff's `FAST` rule family remains lint policy and does not
install a framework.

## Part 1 — Template repository

### Layout

`copier.yml` renders the contents of `template/`. Root documentation, CI, and
test scripts describe and validate the template itself.

```text
repo root/
├── copier.yml
├── README.md
├── AGENTS.md
├── docs/
│   ├── other-modern-python-tools.md
│   └── superpowers/specs/2026-07-07-copier-template-design.md
├── scripts/
│   ├── test-render-contracts.sh
│   └── test-generation.sh
├── .github/workflows/ci.yml
└── template/
    ├── pyproject.toml.jinja
    ├── mise.toml.jinja
    ├── .pre-commit-config.yaml.jinja
    ├── README.md.jinja
    ├── AGENTS.md.jinja
    ├── Dockerfile.jinja
    ├── .dockerignore.jinja
    ├── .hadolint.yaml.jinja
    ├── src/{{ project_name }}/
    ├── tests/unit/{{ project_name }}/
    ├── conditional GitHub automation
    ├── conditional LICENSE
    └── conditional optional-linter configuration
```

Generated projects create `uv.lock` on their first sync. The root template does
not carry a generated-project lockfile, Python project metadata, source tree, or
Python test suite.

Copier filename conditions are limited to genuinely optional files:

- MIT `LICENSE`;
- `.github/workflows/ci.yml`, `.github/dependabot.yml`, `.github/zizmor.yml`,
  and `renovate.json5`;
- jscpd and markdownlint configuration.

### Wizard

The visible questions are:

| Question | Type | Default | Purpose |
| --- | --- | --- | --- |
| `project_name` | string | `my_project` | Project, distribution, and Python package name |
| `project_description` | string | `Project description` | README and metadata |
| `python_version` | string | `3.14` | Python, mise, Ruff, ty, and Docker |
| `license` | choice | `MIT` | MIT, Proprietary, or Skip |
| `author_name` | string | empty | License owner and optional Docker maintainer |
| `use_github_actions` | boolean | `true` | Complete GitHub automation bundle |
| `extra_linters` | multiselect | all | jscpd, typos, and markdownlint |
| `coverage_fail_under` | integer | `80` | Coverage threshold; zero disables it |

`project_name` is used unchanged for display text, distribution metadata, the
source directory, and Python imports. The wizard does not duplicate package and
project naming. It rejects the standard, case-sensitive Python hard-keyword set
but accepts soft keywords. Users should choose a valid Python package name;
other mistakes surface during the generated project's install, import, or lint
steps.

Hidden `python_version_minor` supplies metadata, Ruff, ty, and the Docker base
tag. Hidden `python_version_pin` preserves exact patch answers and maps known
minor answers to reproducible mise pins.

### Packaging

Every generated `pyproject.toml` contains:

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

Hatchling discovers `src/{{ project_name }}` because the distribution and import
package use the same name. There is no explicit wheel-package table. Pytest does
not inject `src` onto `sys.path`, so the suite exercises the installed project.

License behavior remains:

- MIT creates `LICENSE` and `project.license = "MIT"`; the holder is
  `author_name` or falls back to `project_name`.
- Proprietary creates no file and uses `LicenseRef-Proprietary` metadata.
- Skip creates no file and emits no project license metadata.

### Docker baseline

Every project receives `Dockerfile`, `.dockerignore`, and `.hadolint.yaml`.
Hadolint is always pinned in `mise.toml`, represented by `lint-dockerfile`, and
installed as a prek hook. The generated README always documents the Docker
build command.

The Dockerfile:

- uses the selected Python minor;
- emits a maintainer label only when `author_name` is set;
- performs a dependency-only `uv sync` before copying source;
- performs a second `uv sync` that installs the current package;
- retains a neutral Python-version smoke `CMD` until the project chooses its
  real application runtime.

When GitHub automation is enabled, Dependabot always includes its Docker
ecosystem block because the Dockerfile always exists.

### GitHub automation

`use_github_actions` is the only structural switch. When enabled it renders:

- `.github/workflows/ci.yml`;
- `.github/dependabot.yml`;
- `.github/zizmor.yml`;
- `renovate.json5`;
- the `check-jsonschema` development dependency;
- actionlint and zizmor tool pins, tasks, and prek hooks.

When disabled, none of those artifacts or operational references remain. The
Docker and Hadolint baseline is unchanged.

### Optional lint and coverage choices

The `extra_linters` multiselect directly controls jscpd, typos, and markdownlint
tools, tasks, hooks, and configuration files. An empty selection remains valid
and leaves no dangling task references.

`coverage_fail_under` accepts integers from 0 through 100. Positive values emit
the coverage gate; zero omits the active `fail_under` setting.

### Validation scripts and root CI

`scripts/test-render-contracts.sh` performs fast renders without installing the
generated toolchain. It covers:

- Proprietary and Skip licenses;
- Python 3.10 and an exact patch version;
- disabled coverage gate;
- empty optional-linter selection;
- unchanged project-name propagation;
- hard-keyword rejection and soft-keyword acceptance;
- complete GitHub automation on/off behavior;
- unconditional packaging, Docker, and Hadolint.

`scripts/test-generation.sh` accepts exactly two scenario names:

- `github-actions-on`: true wizard defaults;
- `github-actions-off`: the same defaults with only GitHub automation disabled.

Both scenarios render, initialize Git history, install mise tools, sync the
project, import `my_project`, run `uv build`, and pass lint, test, and coverage.
Root CI runs the render contracts and the two named scenarios, optionally as a
scenario matrix.

### Documentation

The root README explains generation, the compact wizard, updates, adoption, and
the three validation commands. Generated documentation describes the project,
its always-available Docker path, and only the automation that was rendered.

## Part 2 — `sample_db` adoption

Adoption into `github.com/Alex-Kopylov/sample_db` remains a separate repository,
branch, and PR. Render from the local template with these project choices:

- project name `sample_db`;
- Python 3.12;
- MIT license;
- GitHub automation enabled;
- all optional linters;
- coverage threshold zero.

Docker is already part of the baseline. Preserve `sample_db`'s domain-specific
Dockerfile and compose behavior while adopting the shared Hadolint gate.

Keep its runtime dependencies and Hatchling metadata, port all Makefile behavior
to mise tasks, reconcile strict lint configuration with targeted exclusions,
replace CI with the generated mise-based workflow, and retain
`.copier-answers.yml` for future updates.

## Verification

- `scripts/test-render-contracts.sh` passes.
- `scripts/test-generation.sh github-actions-on` passes.
- `scripts/test-generation.sh github-actions-off` passes.
- Root CI is green.
- The separate `sample_db` branch passes its lint and test gates when that
  adoption is explicitly undertaken.

## Out of scope

- Selecting an application framework or runtime command.
- Publishing to a template index or adding a documentation site.
- Redesigning the linter policy.
- Functional changes to downstream projects beyond what their gates require.
