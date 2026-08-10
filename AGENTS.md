# AGENTS.md — TestZeus Create & Execute

Guidance for **Claude Code**, **GitHub Copilot**, and other coding agents working in this repository **or** wiring it into a customer CI repo.

Humans: start with [README.md](README.md) and [docs/CONSUMER_SETUP.md](docs/CONSUMER_SETUP.md).

---

## What this project is

CI packaging that:

1. Reads `./tests/test-*` folders (Gherkin `.feature` + optional env / test-data / hypermind)
2. Creates matching TestZeus resources via `testzeus-cli`
3. Runs `test-run-group execute-and-monitor`
4. Writes a CTRF report under `downloads/`

| Platform | Entry | Orchestrator |
|----------|--------|--------------|
| GitHub Actions | `action.yml` → composite | `scripts/entrypoint.sh` |
| GitLab CI | `templates/gitlab-ci.yml` (clone + run) | same |
| Bitbucket | `templates/bitbucket-pipelines.yml` or `bitbucket-pipe/` | same |

Do **not** invent a second orchestration path. Always call `scripts/entrypoint.sh` (or the Action / Pipe that wraps it).

---

## When a customer asks you to “add TestZeus CI”

Follow [docs/CONSUMER_SETUP.md](docs/CONSUMER_SETUP.md) end-to-end. Short checklist:

1. Detect CI: GitHub → Action; GitLab → include template; Bitbucket → pipeline snippet or Pipe.
2. Ensure `./tests/test-*/` exists with at least one `.feature` file (copy [examples/smoke/](examples/smoke/) if they have nothing).
3. Prefer secret `TESTZEUS_TOKEN` (PocketBase JWT). Fallback: `TESTZEUS_EMAIL` + `TESTZEUS_PASSWORD`.
4. Pin version to **`v1`** (Action `@v1`, `TESTZEUS_ACTION_REF=v1`, Pipe image `:v1`) unless they explicitly want a branch for testing.
5. Commit workflow/config + `tests/` + optional `templates/ctrf-report.hbs`.
6. Tell them how to trigger the pipeline and where to download the CTRF artifact.

### Agent do / don’t

| Do | Don’t |
|----|--------|
| Pin `@v1` / `TESTZEUS_ACTION_REF=v1` for production consumers | Point production at `main` or an unmerged feature branch |
| Put auth only in CI secrets / masked variables | Commit tokens, passwords, or JWTs |
| Keep `tests/test-*` naming (`test-` prefix required) | Invent alternate folder layouts |
| On GitLab, set `TESTZEUS_ACTION_REF` at **job** level if overriding the default | Assume top-level `variables:` always wins over includes |
| Reuse [examples/smoke/](examples/smoke/) for first green run | Skip verification |

---

## Auth (agents must get this right)

Preference order inside `scripts/entrypoint.sh` / `scripts/lib.sh`:

1. `TESTZEUS_TOKEN` → CLI `session-exchange` + profile shim (`TESTZEUS_PROFILE`, default `ci`)
2. Else `TESTZEUS_EMAIL` + `TESTZEUS_PASSWORD` → CLI login

| Platform | Where to store |
|----------|----------------|
| GitHub | Repo → Settings → Secrets → `TESTZEUS_TOKEN` (or email/password). Action inputs: `token` / `email` / `password`. |
| GitLab | Settings → CI/CD → Variables → masked `TESTZEUS_TOKEN` (or email/password). Mark protected only if all target branches are protected. |
| Bitbucket | Repository variables → secured `TESTZEUS_TOKEN` (or email/password). |

Never print secrets in logs. If login fails, ask the user to rotate/check the secret — do not embed credentials in YAML.

---

## Repository contract (`./tests`)

Minimum:

```text
tests/
└── test-<name>/
    └── <anything>.feature
```

Optional per test: `environment/` (`data.txt`, `extra.json`, `assets/`), `test-data/<case>/data.txt`, `hypermind/` files.

Reference fixture: [examples/smoke/](examples/smoke/).

Working directory for the job **must** be the consumer repo root so `./tests` resolves.

---

## Platform recipes (copy targets)

### GitHub Actions

```yaml
- uses: actions/checkout@v4
- uses: test-zeus-ai/testzeus-create-execute@v1
  with:
    token: ${{ secrets.TESTZEUS_TOKEN }}
    name: 'CI Smoke Tests'
    execution_mode: 'lenient'
    filename: 'ctrf-report.json'
```

CTRF path: `downloads/<filename>`. Optional pretty PR report: `ctrf-io/github-test-reporter` with `if: always()`.

### GitLab CI

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/test-zeus-ai/testzeus-create-execute/v1/templates/gitlab-ci.yml'

testzeus-create-execute:
  extends: .testzeus-create-execute
  stage: test
  variables:
    # Job-level pin is the reliable override (include merge can ignore top-level vars)
    TESTZEUS_ACTION_REF: "v1"
    TEST_RUN_NAME: "CI Smoke Tests"
    EXECUTION_MODE: "lenient"
    REPORT_FILENAME: "ctrf-report.json"
```

CI/CD Variables: `TESTZEUS_TOKEN` (masked). Artifact: `ctrf-report.json` + `downloads/`.

### Bitbucket Pipelines

Copy [templates/bitbucket-pipelines.yml](templates/bitbucket-pipelines.yml), or:

```yaml
script:
  - pipe: docker://ghcr.io/test-zeus-ai/testzeus-create-execute:v1
    variables:
      TESTZEUS_TOKEN: $TESTZEUS_TOKEN
      TEST_RUN_NAME: "CI Smoke Tests"
```

---

## Env vars (shared)

| Variable | Required | Default | Notes |
|----------|----------|---------|-------|
| `TESTZEUS_TOKEN` | Preferred | — | JWT |
| `TESTZEUS_EMAIL` / `TESTZEUS_PASSWORD` | Fallback | — | When token unset |
| `TEST_RUN_NAME` | No | `Smoke action suite` | |
| `EXECUTION_MODE` | No | `lenient` | `lenient` \| `strict` |
| `REPORT_FILENAME` | No | `ctrf-report.json` | Written under `downloads/` |
| `NOTIFICATION_CHANNELS` | No | empty | Comma-separated IDs |
| `TESTZEUS_ACTION_REF` | GitLab/BB clone | `v1` | Git tag/branch to clone |
| `TESTZEUS_SKIP_INSTALL` | Pipe image | unset | `true` skips `pip install` |
| `TESTZEUS_PROFILE` | Token auth | `ci` | CLI profile name |

Runtime needs: `bash`, `python`/`pip`, `jq`, network to TestZeus + PyPI (unless skip install).

---

## Working in *this* repository (maintainers)

| Area | Location |
|------|----------|
| Shared entry | `scripts/entrypoint.sh`, `scripts/lib.sh` |
| Create + execute | `scripts/create_test_report.sh` |
| GH Action | `action.yml` |
| GitLab | `templates/gitlab-ci.yml`, `templates/create-execute/` |
| Bitbucket | `templates/bitbucket-pipelines.yml`, `bitbucket-pipe/` |
| Smoke fixture | `examples/smoke/` |
| CI lint | `.github/workflows/ci.yml` (`bash -n`, shellcheck) |
| Self-test | `.github/workflows/self-test.yml` |
| Release / GHCR | `.github/workflows/release.yml` on `v*` tags |

Rules:

- Keep adapters thin: map secrets → env → `entrypoint.sh`.
- Prefer `TESTZEUS_TOKEN` paths; keep email/password for backward compatibility.
- Do not break existing GitHub Action users who still pass `email`/`password`.
- After script changes: ensure `ci.yml` / shellcheck stay green; run self-test when auth secrets exist.
- Document consumer-facing behavior in README + `docs/CONSUMER_SETUP.md`; keep this file for agent procedure.

---

## Verification

1. Pipeline job logs show auth success (no credential values).
2. Job finds `./tests/test-*` and creates/runs resources.
3. Artifact `downloads/<REPORT_FILENAME>` (or configured name) is present.
4. Failures: see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

Local smoke from repo root:

```bash
ln -sfn examples/smoke/tests tests
export TESTZEUS_TOKEN='...'
./scripts/entrypoint.sh
```

---

## Known pitfall: GitLab `TESTZEUS_ACTION_REF`

If the job clones an old tag (missing `scripts/entrypoint.sh`), the ref is wrong.

- Template shells default to `v1` via `${TESTZEUS_ACTION_REF:-v1}`.
- To pin a branch/tag, set `TESTZEUS_ACTION_REF` on the **job** (`testzeus-create-execute.variables`), not only at the pipeline top level after `include:`.
- Confirm in logs: `Cloning testzeus-create-execute@<ref>`.

---

## Doc map

| Doc | Audience |
|-----|----------|
| [README.md](README.md) | Humans — features, structure, deep reference |
| [docs/CONSUMER_SETUP.md](docs/CONSUMER_SETUP.md) | Humans + agents — E2E setup per CI |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Failures and fixes |
| [examples/smoke/README.md](examples/smoke/README.md) | Minimal fixture |
| This file | Agents implementing or integrating create-execute |
