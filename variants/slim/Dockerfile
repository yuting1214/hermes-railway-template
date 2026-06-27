# syntax=docker/dockerfile:1
#
# Hermes-Agent — SLIM variant (CLI + messaging gateway only, no Node/Playwright).
# Smallest RAM/image; driven over `railway ssh` + tmux, answers messaging 24/7
# via `hermes gateway run`. Data lives on a Railway volume at /data (HERMES_HOME).
#
# Build args:
#   HERMES_REF     git ref to install (default: main → always-latest upstream).
#                  Pin to a tag/sha (e.g. v0.16.0) for reproducible builds.
#   HERMES_EXTRAS  pip extras (default: messaging → Telegram/Discord/Slack adapters
#                  eager-installed so the always-on bot never needs a runtime pip).
FROM python:3.12-slim AS base

ARG HERMES_REF=main
ARG HERMES_EXTRAS=messaging

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HERMES_HOME=/data \
    HOME=/data \
    MALLOC_ARENA_MAX=2 \
    PATH="/opt/venv/bin:$PATH"

# Runtime deps only: ripgrep (Hermes file-search tool), git, tmux (session
# persistence for `railway ssh`), ca-certificates/curl (TLS), procps (ps — used
# by gateway status). build tools are added then removed in one layer so any
# source-only wheels resolve without bloating the final image.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep tmux procps build-essential; \
    python -m venv /opt/venv; \
    /opt/venv/bin/pip install --upgrade pip; \
    /opt/venv/bin/pip install \
        "hermes-agent[${HERMES_EXTRAS}] @ git+https://github.com/nousresearch/hermes-agent.git@${HERMES_REF}"; \
    apt-get purge -y --auto-remove build-essential; \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. The persistent
# volume is attached out-of-band: `railway volume add -m /data` (see docs).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
