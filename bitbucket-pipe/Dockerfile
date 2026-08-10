FROM python:3.12-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends jq git ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY scripts/ /opt/testzeus-create-execute/scripts/
RUN chmod +x /opt/testzeus-create-execute/scripts/*.sh \
  && pip install --no-cache-dir --upgrade testzeus-cli python-dateutil

ENV TESTZEUS_SKIP_INSTALL=true
WORKDIR /opt/atlassian/pipelines/agent/build

ENTRYPOINT ["/opt/testzeus-create-execute/scripts/entrypoint.sh"]
