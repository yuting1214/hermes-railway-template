# syntax=docker/dockerfile:1
#
# Hermes-Agent — SLIM variant (CLI + messaging gateway only, no Node/Playwright).
# Smallest RAM/image; driven over `railway ssh`, answers messaging 24/7
# via `hermes gateway run`. Data lives on a Railway volume at /data (HERMES_HOME).
#
# Build args:
#   HERMES_REF     git ref to install. Defaults to a pinned CalVer release tag
#                  (see ARG below) for reproducible builds — upstream tags are
#                  date-versioned (e.g. v2026.6.19), NOT the v0.x package version.
#                  Override with another tag/sha, or `main` for always-latest.
#   HERMES_EXTRAS  pip extras (default: messaging → Telegram/Discord/Slack adapters
#                  eager-installed so the always-on bot never needs a runtime pip).
FROM python:3.12-slim AS base

ARG HERMES_REF=v2026.6.19
ARG HERMES_EXTRAS=messaging

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HERMES_HOME=/data \
    HOME=/data \
    MALLOC_ARENA_MAX=2 \
    PATH="/opt/venv/bin:$PATH"

# Runtime deps only: ripgrep (Hermes file-search tool), git, ca-certificates/curl
# (TLS), procps (ps — used by gateway status). build tools are added then removed
# in one layer so any source-only wheels resolve without bloating the final image.
# (No tmux: `railway ssh --session` provisions it on demand when you want one.)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep procps build-essential; \
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
