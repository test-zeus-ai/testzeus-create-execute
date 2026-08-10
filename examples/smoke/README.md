# Smoke example

Minimal consumer layout for validating create-execute end-to-end.

For full GitHub / GitLab / Bitbucket wiring, see [docs/CONSUMER_SETUP.md](../../docs/CONSUMER_SETUP.md). Agents: [AGENTS.md](../../AGENTS.md).

## Layout

```text
examples/smoke/
└── tests/
    └── test_smoke/
        └── smoke.feature
```

## Local run

From a working directory that contains `./tests` (copy or symlink this folder's `tests/`):

```bash
export TESTZEUS_TOKEN='...'          # preferred
# or: export TESTZEUS_EMAIL='...' TESTZEUS_PASSWORD='...'

export TEST_RUN_NAME='Local smoke'
export EXECUTION_MODE='lenient'
export REPORT_FILENAME='ctrf-report.json'

../../scripts/entrypoint.sh
```

From the repo root:

```bash
ln -sfn examples/smoke/tests tests
./scripts/entrypoint.sh
```

## GitHub self-test

Use the `self-test` workflow (`workflow_dispatch`) which copies this fixture to `./tests` and runs the composite action via `uses: ./`.
