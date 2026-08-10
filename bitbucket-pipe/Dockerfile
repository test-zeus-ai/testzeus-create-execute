FROM python:3.12-slim

ARG TESTZEUS_CLI_VERSION=0.0.30

RUN apt-get update \
  && apt-get install -y --no-install-recommends jq git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/ /opt/testzeus-create-execute/scripts/
RUN chmod +x /opt/testzeus-create-execute/scripts/*.sh \
  && pip install --no-cache-dir "testzeus-cli==${TESTZEUS_CLI_VERSION}" python-dateutil

ENV TESTZEUS_SKIP_INSTALL=true
# Bitbucket Pipelines mount point. For local `docker run`, mount the consumer
# repo at this path (or override WORKDIR).
WORKDIR /opt/atlassian/pipelines/agent/build

ENTRYPOINT ["/opt/testzeus-create-execute/scripts/entrypoint.sh"]
