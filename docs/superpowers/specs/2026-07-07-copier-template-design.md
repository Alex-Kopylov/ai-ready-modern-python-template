# Copier-based template transformation — design spec

Date: 2026-07-07
Status: approved by user (layout, wizard scope, sample_db strategy, delivery
confirmed via Q&A).

## Goal

Transform `ai-ready-modern-python-template` into a
[copier](https://copier.readthedocs.io/) template with a low-friction wizard:

1. **Quick path** — user answers ~3 questions, gets recommended defaults.
2. **Custom path** — user opts in to ~8 coarse feature questions.
3. Everything finer-grained (individual lint rules, tool configs) remains a
   direct file edit after generation — NOT a wizard question.

Then validate by adopting the template into an existing real project,
`github.com/Alex-Kopylov/sample_db`, delivered as a branch + PR.

## Part 1 — Template repo restructure

### Layout (`_subdirectory: template`)

```
repo root/
├── copier.yml                  # wizard definition
├── README.md                   # template usage docs (rewritten)
├── LICENSE                     # template's own MIT license
├── AGENTS.md                   # template-development instructions (rewritten)
├── docs/
│   ├── other-modern-python-tools.md   # stays at root (template-level doc)
│   └── superpowers/specs/...          # this spec
├── scripts/
│   └── test-generation.sh      # generate + gate a project locally; used by CI
├── .github/workflows/ci.yml    # template CI (see below)
└── template/                   # everything a generated project receives
    ├── pyproject.toml.jinja
    ├── mise.toml.jinja
    ├── .pre-commit-config.yaml.jinja
    ├── README.md.jinja
    ├── AGENTS.md.jinja
    ├── .python-version.jinja
    ├── .copier-answers.yml.jinja
    ├── LICENSE handling (conditional, see below)
    ├── docs/lint-strategy.md            # moves here (referenced by AGENTS.md)
    ├── .ruff.toml, .flake8, .yamllint, taplo.toml, .vulture.toml,
    │   .bandit, .shellcheckrc, .pytest.ini, .gitignore   # verbatim copies
    ├── src/{{ package_name }}/{__init__.py, main.py}
    ├── tests/{__init__.py, unit/__init__.py,
    │          unit/{{ package_name }}/{__init__.py, test_main.py}}
    ├── conditional: Dockerfile, .dockerignore, .hadolint.yaml
    ├── conditional: .github/ (workflows/ci.yml.jinja, dependabot.yml.jinja,
    │                zizmor.yml), renovate.json5
    ├── conditional: .jscpd.json
    └── conditional: .markdownlint.jsonc, .markdownlint-cli2.jsonc
```

- `uv.lock` is **not** templated. Generated projects create it via
  `uv sync`/`uv lock`. Delete root `uv.lock`, `src/`, `tests/`,
  `pyproject.toml` etc. as they move into `template/`.
- Conditional files use copier filename conditions, e.g.
  `{% if use_docker %}Dockerfile{% endif %}` and
  `{% if use_github_actions %}.github{% endif %}/…`.

### copier.yml

Settings: `_subdirectory: template`, `_answers_file: .copier-answers.yml`,
`_min_copier_version` set to the lowest version supporting `multiselect`
choices (verify against copier docs; believed 9.x — check).

**Always asked:**

| question | type | default |
|---|---|---|
| `project_name` | str, validated non-empty | placeholder `my-project` |
| `package_name` | str, validated `^[a-z_][a-z0-9_]*$` | derived: `{{ project_name \| lower \| replace('-', '_') \| replace(' ', '_') }}` |
| `project_description` | str | `"Project description"` |
| `setup_mode` | choice: `quick` ("Quick — recommended defaults: Python 3.14, Docker, GitHub Actions, all linters, MIT") / `custom` ("Custom — configure features in depth") | `quick` |

**Custom-only** (each has `when: "{{ setup_mode == 'custom' }}"`; defaults
apply silently in quick mode):

| question | type | default | drives |
|---|---|---|---|
| `python_version` | str, validated `^3\.\d+(\.\d+)?$` and minor `>= 10`; accepts a minor like `3.13` or exact patch like `3.13.2` | 3.14 | `requires-python`, ty env, mise pin, `.python-version` |
| `license` | choice MIT / Proprietary / Skip | MIT | pyproject `license`, LICENSE file presence/content; Skip means define later and do not create a LICENSE file |
| `author_name` | str | `""` (falls back to `project_name` in LICENSE) | MIT LICENSE copyright line |
| `is_package` | bool | `false` | hatchling `[build-system]` + wheel target vs virtual project |
| `use_docker` | bool | `true` | Dockerfile, .dockerignore, .hadolint.yaml, hadolint tool/task/hook |
| `use_github_actions` | bool | `true` | `.github/`, renovate.json5, actionlint/zizmor/check-jsonschema tool/tasks/hooks |
| `extra_linters` | multiselect: jscpd / typos / markdownlint | all selected | tool pins, tasks, hooks, config files per selection |
| `coverage_fail_under` | int | `80` | `[tool.coverage.report] fail_under` (omit/comment when 0) |

**Computed (hidden, `when: false`):** `python_version_minor` keeps the first two
components for metadata, while `python_version_pin` passes exact patch answers
through and maps known minor answers to pinned patches for mise/.python-version.

**Post-copy message** (`_message_after_copy`): next steps — `cd`, `git init`
+ initial commit, `mise install`, `mise run install`, `mise run
install-hooks`, `mise run lint`, note that `uv.lock` gets created on first
sync and should be committed. No `_tasks` — keep generation side-effect-free.

### Jinja templating of project files

- `pyproject.toml.jinja`: name/description/requires-python/license from
  answers; `check-jsonschema` dev dep only when `use_github_actions`;
  omit project license metadata when license is Skip;
  conditional `[build-system]` (hatchling) + `[tool.hatch.build.targets.wheel]
  packages = ["src/{{ package_name }}"]` when `is_package`, otherwise keep the
  virtual-project comment; `[tool.ty.environment]` python-version;
  coverage `fail_under` when > 0.
- `mise.toml.jinja`: python pin; node + npm:jscpd / npm:markdownlint-cli2
  pins only when the respective linters are selected (drop node entirely when
  neither is); hadolint only when `use_docker`; actionlint/zizmor only when
  `use_github_actions`. Task groups `lint-fast`/`lint-full` include only the
  tasks that exist. Keep TOML valid under all combinations.
- `.pre-commit-config.yaml.jinja`: conditionally include hadolint,
  actionlint, zizmor, check-jsonschema-github-workflows, jscpd, typos hooks.
- `README.md.jinja`: rewritten for a *generated project* — project name
  heading, description, quick start. Template-marketing prose stays in the
  root README instead.
- `AGENTS.md.jinja`: replace "this is a new repository template" framing with
  generated-project framing; command list reflects enabled features.
- LICENSE: `{% if license == 'MIT' %}LICENSE{% endif %}.jinja` with MIT text,
  year 2026, holder `author_name or project_name`; Proprietary and Skip do not
  create a LICENSE file.
- `.copier-answers.yml.jinja`: standard
  `# Changes here will be overwritten by Copier` +
  `{{ _copier_answers|to_nice_yaml -}}`.

### Template CI (root `.github/workflows/ci.yml`)

Replaces the current project CI. Jobs:

1. **lint-template**: yamllint on copier.yml + workflows, actionlint, zizmor.
2. **generate-and-gate** (matrix): four answer sets —
   `defaults` (quick mode), `everything-off` (custom: no docker, no GHA, no
   extra linters, Skip, 3.10), `everything-on` (custom: all on, package mode,
   coverage 80, 3.13), and `github-actions-no-docker` (custom: GHA on, Docker
   off, Proprietary, 3.12). For each: `uvx copier copy --defaults
   --data-file <answers.yml> . /tmp/gen`, then inside: `git init` + commit
   (gitleaks needs history), `mise trust && mise install`, `mise run install`,
   `mise run lint`, `mise run test`, and `mise run
   test-cov`. The matrix must prove that each covered feature combination
   yields valid TOML/YAML and a passing gate.

`scripts/test-generation.sh` wraps the per-matrix-entry steps so it can run
locally too.

### Root README rewrite

Usage: `uvx copier copy gh:Alex-Kopylov/ai-ready-modern-python-template
my-project` (note: copier resolves the latest git tag; tag `v1.0.0` after
merge — include a "Releasing" note in AGENTS.md). Document quick vs custom,
the update workflow (`uvx copier update`), adopting an existing project
(`copier copy` into it, review `git diff`), and the philosophy: coarse
toggles in the wizard, fine tuning via file edits.

## Part 2 — sample_db adoption (separate repo, branch + PR)

Clone `github.com/Alex-Kopylov/sample_db` to
`~/PycharmProjects/sample_db`, branch `adopt-ai-template`.

Run the wizard from the local template checkout:
`uvx copier copy --vcs-ref=HEAD --data …` with answers: project_name
`sample-db`, package_name `sample_db`, custom mode, python 3.12 (deps
require it), MIT, `is_package: true` (keeps hatchling), docker on, GHA on,
all extra linters, coverage 0.

Merge strategy:

- **pyproject.toml**: keep their `[project]` dependencies and hatchling
  build config; adopt template dev-group additions (deptry, bandit, prek,
  yamllint, check-jsonschema, pytest-xdist, pytest-cov) alongside their
  existing dev deps (langgraph-cli stays). Move their inline
  `[tool.vulture]` to `.vulture.toml` (template convention).
- **Dockerfile / docker-compose**: keep theirs (domain-specific);
  hadolint gate applies to it — fix findings or add targeted ignores in
  `.hadolint.yaml`.
- **Makefile → mise, full migration**: port ALL targets (setup, lint,
  format, db, test, run, e2e, docker-build/up/down/clean/logs/psql/
  validate-rls/docker-e2e) into `mise.toml` tasks, then delete the
  Makefile. Preserve behavior incl. env defaults (HOST/PORT/E2E_PORT,
  UV_CACHE_DIR) via mise task env or `[env]`. Update README.md and
  HOW_TO_TEST_IT_WORKS.md references from `make x` to `mise run x`.
- **CI**: replace with the template's mise-based ci.yml.
- **Configs**: adopt template `.ruff.toml`, `.flake8`, `.yamllint`, etc.,
  reconciling with their existing `.ruff.toml`/`.flake8` (prefer template
  strictness; keep their genuinely needed excludes).
- **Lint fallout**: run `mise run lint` + `mise run test`; fix findings.
  Prefer targeted config excludes over large code churn (e.g. jscpd
  threshold/excludes for generated-looking code, typos allowlist,
  vulture whitelist). `uv audit` CVEs in their deps: upgrade patch-level
  where safe, otherwise document in the PR body rather than force
  upgrades. gitleaks scans history — if it flags something real, surface
  it in the PR body, do NOT rewrite history.
- Add `.copier-answers.yml` so sample_db can `copier update` later.

Deliverable: pushed branch + PR on sample_db with a body explaining what
was adopted, what was intentionally kept, and any surfaced issues.

## Verification

- Template repo: `scripts/test-generation.sh` passes locally for all four
  matrix answer sets; template CI green on the PR.
- sample_db: `mise run lint` and `mise run test` pass locally on the
  branch; its CI green on the PR.

## Out of scope

- Publishing to a template index; docs sites.
- Changing the template's linter selection/strictness (transform, don't
  redesign).
- sample_db functional changes beyond what gates require.
