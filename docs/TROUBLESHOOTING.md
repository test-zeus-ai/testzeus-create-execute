# Troubleshooting

Agents: match the symptom, apply the fix, re-run CI. Do not invent alternate entrypoints.

---

## `chmod: cannot access '.../scripts/entrypoint.sh'`

**Cause:** GitLab/Bitbucket cloned a ref that does not contain the multi-SCM layout (often the old `v1` tag or wrong branch).

**Fix:**

1. Set `TESTZEUS_ACTION_REF` to a tag/branch that has `scripts/entrypoint.sh` (current releases: `v1` after the multi-SCM release; for PR testing use the feature branch name).
2. On **GitLab**, set it on the **job**:

```yaml
testzeus-create-execute:
  extends: .testzeus-create-execute
  variables:
    TESTZEUS_ACTION_REF: "v1"
```

3. Confirm the log line: `Cloning testzeus-create-execute@<ref>`.

Top-level `variables:` after `include:` alone may not override included defaults — prefer job-level.

---

## Login / session-exchange failed

**Cause:** Missing or invalid credentials; wrong variable names; protected variable on unprotected branch (GitLab).

**Fix:**

- Prefer `TESTZEUS_TOKEN`. Fallback: both `TESTZEUS_EMAIL` and `TESTZEUS_PASSWORD`.
- GitHub: Action `with.token` / secrets must match.
- GitLab: Variable **Masked**; unprotect if the branch is not protected.
- Bitbucket: **Secured** repository variable.
- Never commit credentials. Rotate if they appeared in chat or plaintext logs.

---

## No `.feature` file / no `tests/test-*`

**Cause:** Wrong working directory or folder naming.

**Fix:**

- Job cwd must be the consumer repo root (`actions/checkout` / default GitLab-Bitbucket checkout).
- Directories must be `tests/test-<name>/` with a `.feature` inside.
- Start from [examples/smoke/](../examples/smoke/).

---

## `jq: command not found` / `pip` failures

**Cause:** Slim images without tools; network blocked.

**Fix:**

- Templates already `apt-get install jq git ca-certificates`.
- Ensure PyPI is reachable unless using the Pipe with `TESTZEUS_SKIP_INSTALL=true`.
- GitHub-hosted `ubuntu-latest` is fine for the composite Action.

---

## CTRF / artifact missing

**Cause:** Job failed before report write; wrong path; artifact paths misconfigured.

**Fix:**

- Report path contract: `downloads/<REPORT_FILENAME>` (default `downloads/ctrf-report.json`) — written with `--output-dir downloads`.
- GitLab / Bitbucket artifact paths should include `downloads/`.
- GitHub reporter / upload-artifact should use `downloads/<filename>`.
- Open job logs for create/execute errors before the artifact step.

## Login prints ✅ but later steps fail

**Cause (fixed in current scripts):** older password login used `|| true` and grepped for `Login failed`, treating other failures as success.

**Fix:** Use a release that checks the CLI exit code for `testzeus login`. Wrong password must abort the job.

---

## Old `v1` tag behavior

Historical `v1` tags may predate `scripts/entrypoint.sh`. After merging multi-SCM support, maintainers should move floating `v1` to a release that includes the entrypoint. Until then, pin consumers to a known-good tag or document the required tag in release notes.

---

## Debug tips

| Platform | Tip |
|----------|-----|
| GitHub | `ACTIONS_STEP_DEBUG=true` in the job env |
| All | Echo non-secret config: `TEST_RUN_NAME`, `EXECUTION_MODE`, `TESTZEUS_ACTION_REF` |
| Local | `ln -sfn examples/smoke/tests tests && TESTZEUS_TOKEN=... ./scripts/entrypoint.sh` |

More context: [README.md — Troubleshooting](../README.md#troubleshooting), [CONSUMER_SETUP.md](CONSUMER_SETUP.md).
