# GitHub Copilot — TestZeus Create & Execute

Follow **[AGENTS.md](../AGENTS.md)** for maintainer work and customer CI integrations.

End-to-end consumer setup: **[docs/CONSUMER_SETUP.md](../docs/CONSUMER_SETUP.md)**.  
Troubleshooting: **[docs/TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md)**.

Prefer `TESTZEUS_TOKEN`, pin consumers to `@v1` / `TESTZEUS_ACTION_REF=v1`, and always use `scripts/entrypoint.sh` (or the Action/Pipe wrappers). On GitLab, override `TESTZEUS_ACTION_REF` at **job** level.
