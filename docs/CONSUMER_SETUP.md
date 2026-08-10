# End-to-end consumer setup

Wire **testzeus-create-execute** into a customer repository so CI creates TestZeus tests from `./tests`, executes them, and publishes a CTRF report.

Agents: also read [AGENTS.md](../AGENTS.md).

---

## Overview (all platforms)

```text
Customer repo
  ./tests/test-*          ← feature files (+ optional env / data / hypermind)
  CI config               ← Action | GitLab include | Bitbucket pipeline/pipe
       ↓
  scripts/entrypoint.sh   ← install CLI → auth → create_test_report.sh
       ↓
  downloads/<report>.json ← CTRF artifact
```

**Pin:** production consumers use **`v1`** (`@v1`, `TESTZEUS_ACTION_REF=v1`, image `:v1`).

**Auth (preferred):** masked/secured `TESTZEUS_TOKEN` (PocketBase JWT).  
**Auth (fallback):** `TESTZEUS_EMAIL` + `TESTZEUS_PASSWORD`.

---

## Step 0 — Prerequisites (every platform)

1. Active TestZeus account / tenant.
2. A JWT (`TESTZEUS_TOKEN`) or login email/password.
3. Customer repo with write access to add CI config + `tests/`.
4. Runner with outbound HTTPS to TestZeus and PyPI (Pipe image may skip pip).

---

## Step 1 — Add `./tests` layout

Minimum:

```text
tests/
└── test-smoke/
    └── smoke.feature
```

Copy from this repo if needed:

```bash
# from a clone of testzeus-create-execute
cp -R examples/smoke/tests ./tests
```

Rules:

- Top-level dirs must match `tests/test-*`.
- Each test dir needs exactly one `.feature` file (name can vary).
- Optional: `environment/`, `test-data/<case>/data.txt`, `hypermind/`.
- Deep reference: [README.md](../README.md) (Repository Structure).

Optional CTRF Handlebars template for GitHub pretty reports:

```text
templates/ctrf-report.hbs   # or templates/testzeus-report.hbs — match your workflow path
```

---

## Step 2 — Choose your CI and add config

### A) GitHub Actions

1. Repo → **Settings → Secrets and variables → Actions**  
   - Add `TESTZEUS_TOKEN` (or `TESTZEUS_EMAIL` + `TESTZEUS_PASSWORD`).
2. Add `.github/workflows/testzeus.yml`:

```yaml
name: TestZeus

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  testzeus:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create & execute
        uses: test-zeus-ai/testzeus-create-execute@v1
        with:
          token: ${{ secrets.TESTZEUS_TOKEN }}
          # email: ${{ secrets.TESTZEUS_EMAIL }}
          # password: ${{ secrets.TESTZEUS_PASSWORD }}
          name: 'CI Smoke Tests'
          execution_mode: 'lenient'
          filename: 'ctrf-report.json'

      - name: Publish CTRF (optional)
        if: always()
        uses: ctrf-io/github-test-reporter@v1
        with:
          report-path: 'downloads/ctrf-report.json'
          template-path: 'templates/ctrf-report.hbs'
          custom-report: true
```

3. Commit + push (or run **workflow_dispatch**).
4. Open the workflow run → download `downloads/ctrf-report.json` from artifacts (if you add an `actions/upload-artifact` step) or inspect the Action log / reporter comment.

Upload artifact example:

```yaml
      - if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ctrf-report
          path: downloads/ctrf-report.json
```

---

### B) GitLab CI

1. Project → **Settings → CI/CD → Variables**  
   - `TESTZEUS_TOKEN` = JWT, **Masked**, unprotect if needed for unprotected branches.  
   - Or `TESTZEUS_EMAIL` + `TESTZEUS_PASSWORD`.
2. Add `.gitlab-ci.yml`:

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/test-zeus-ai/testzeus-create-execute/v1/templates/gitlab-ci.yml'

testzeus-create-execute:
  extends: .testzeus-create-execute
  stage: test
  variables:
    # Set on the job — reliable override of included defaults
    TESTZEUS_ACTION_REF: "v1"
    TEST_RUN_NAME: "CI Smoke Tests"
    EXECUTION_MODE: "lenient"
    REPORT_FILENAME: "ctrf-report.json"
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_PIPELINE_SOURCE == "web"
    - if: $CI_PIPELINE_SOURCE == "api"
```

3. Ensure `./tests` is committed on the branch that runs CI.
4. Run pipeline (push, MR, or **CI/CD → Pipelines → Run**).
5. Job log should show `Cloning testzeus-create-execute@v1` then entrypoint progress.
6. Download job artifacts: `ctrf-report.json` / `downloads/`.

**GitLab component** (when vendored on your GitLab):

```yaml
include:
  - component: $CI_SERVER_FQDN/<group>/testzeus-create-execute/create-execute@v1
    inputs:
      name: "CI Smoke Tests"
      execution_mode: "lenient"
      filename: "ctrf-report.json"
      action_ref: "v1"
```

---

### C) Bitbucket Pipelines

1. Repository → **Repository settings → Repository variables**  
   - Secured `TESTZEUS_TOKEN` (or email/password).
2. **Option 1 — clone + entrypoint** (copy [templates/bitbucket-pipelines.yml](../templates/bitbucket-pipelines.yml)):

```yaml
image: python:3.12-slim

pipelines:
  default:
    - step:
        name: TestZeus create-execute
        script:
          - apt-get update && apt-get install -y --no-install-recommends jq git ca-certificates
          - export TESTZEUS_ACTION_REF="${TESTZEUS_ACTION_REF:-v1}"
          - export TEST_RUN_NAME="${TEST_RUN_NAME:-CI Smoke Tests}"
          - export EXECUTION_MODE="${EXECUTION_MODE:-lenient}"
          - export REPORT_FILENAME="${REPORT_FILENAME:-ctrf-report.json}"
          - git clone --depth 1 --branch "${TESTZEUS_ACTION_REF}" https://github.com/test-zeus-ai/testzeus-create-execute.git /tmp/testzeus-create-execute
          - chmod +x /tmp/testzeus-create-execute/scripts/entrypoint.sh
          - /tmp/testzeus-create-execute/scripts/entrypoint.sh
        artifacts:
          - "*.json"
          - downloads/**
```

3. **Option 2 — Pipe image** (after a `v*` release publishes GHCR):

```yaml
script:
  - pipe: docker://ghcr.io/test-zeus-ai/testzeus-create-execute:v1
    variables:
      TESTZEUS_TOKEN: $TESTZEUS_TOKEN
      TEST_RUN_NAME: "CI Smoke Tests"
      EXECUTION_MODE: "lenient"
      REPORT_FILENAME: "ctrf-report.json"
```

4. Enable Pipelines, push, open the step → download artifacts.

---

## Step 3 — Verify success

| Check | Expected |
|-------|----------|
| Auth | No login/session-exchange error |
| Discovery | Logs mention creating tests from `./tests/test-*` |
| Execute | Run group monitor completes |
| Report | `downloads/<REPORT_FILENAME>` exists as artifact |
| Clone ref (GL/BB) | Log shows intended tag/branch (e.g. `v1`) |

Local dry-run (machine with Python + network):

```bash
export TESTZEUS_TOKEN='...'
# cwd = consumer repo root with ./tests
# clone create-execute once, then:
/path/to/testzeus-create-execute/scripts/entrypoint.sh
```

---

## Step 4 — Harden for production

- Keep pin on `v1`; bump deliberately when release notes say so.
- Prefer token over password; rotate if leaked in chat/logs.
- Use `execution_mode: strict` only when you want the job to fail on test failures (confirm product behavior for your tenant).
- Restrict protected secrets to protected branches if your process requires it.
- Do not commit `.env` with real credentials.

---

## Inputs / variables cheat sheet

| Concept | GitHub Action `with:` | GitLab / Bitbucket env |
|---------|----------------------|-------------------------|
| Token | `token` | `TESTZEUS_TOKEN` |
| Email | `email` | `TESTZEUS_EMAIL` |
| Password | `password` | `TESTZEUS_PASSWORD` |
| Run name | `name` | `TEST_RUN_NAME` |
| Mode | `execution_mode` | `EXECUTION_MODE` |
| Report file | `filename` | `REPORT_FILENAME` |
| Notify | `notification_channels` | `NOTIFICATION_CHANNELS` |
| Script ref | _(bundled in Action)_ | `TESTZEUS_ACTION_REF` |

Full tables: [README.md — Shared environment variables](../README.md#shared-environment-variables).

---

## Next

- Failures → [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Feature / folder deep dive → [README.md](../README.md)
- Maintainer / agent procedures → [AGENTS.md](../AGENTS.md)
