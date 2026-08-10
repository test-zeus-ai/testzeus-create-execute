# Bitbucket Pipe image

Docker image used as:

```yaml
script:
  - pipe: docker://ghcr.io/test-zeus-ai/testzeus-create-execute:v1
    variables:
      TESTZEUS_TOKEN: $TESTZEUS_TOKEN
      TEST_RUN_NAME: "CI Smoke Tests"
```

## WORKDIR

The image `WORKDIR` is `/opt/atlassian/pipelines/agent/build` — Bitbucket Pipelines mounts the consumer repository there.

For local debugging with `docker run`, mount your repo at that path:

```bash
docker run --rm \
  -e TESTZEUS_TOKEN \
  -v "$PWD:/opt/atlassian/pipelines/agent/build" \
  -w /opt/atlassian/pipelines/agent/build \
  ghcr.io/test-zeus-ai/testzeus-create-execute:v1
```

`TESTZEUS_SKIP_INSTALL=true` is set in the image; the pinned `testzeus-cli` is already installed.
