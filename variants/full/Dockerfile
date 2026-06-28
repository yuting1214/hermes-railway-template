# syntax=docker/dockerfile:1
#
# Hermes-Agent — FULL / UI variant, BUILT FROM SOURCE.
#
# Why from source: the official image `ghcr.io/nousresearch/hermes-agent` is a
# PRIVATE GHCR package (anonymous pull → 403), and the dashboard frontend
# (`hermes_cli/web_dist`) is git-ignored, so a pip-install-from-git has no UI.
# So we build the first-party `hermes dashboard` ourselves:
#   stage 1 (Node 22) → vite-build web/ into hermes_cli/web_dist
#   stage 2 (Python)  → install the package, serve dashboard + gateway
#
# Data lives on a Railway volume at /opt/data (HERMES_HOME). Attach it with
# `railway volume add -m /opt/data` (no Docker VOLUME instruction — Railway
# rejects it).
ARG HERMES_REF=main

# ---- Stage 1: build the dashboard frontend ----
FROM node:22-bookworm-slim AS web
ARG HERMES_REF
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${HERMES_REF}" https://github.com/nousresearch/hermes-agent.git . 2>/dev/null \
 || git clone --depth 1 https://github.com/nousresearch/hermes-agent.git .
# Drop the heavy Electron desktop workspace; build only the web dashboard.
# `npm run build` (web) = `tsc -b && vite build` → outputs to hermes_cli/web_dist.
RUN rm -rf apps \
 && npm install --no-audit --no-fund \
 && npm run build --workspace web \
 && rm -rf node_modules web/node_modules ui-tui/node_modules .git

# ---- Stage 2: python runtime (dashboard + gateway) ----
FROM python:3.12-slim
ARG HERMES_REF
ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HERMES_HOME=/opt/data \
    HOME=/opt/data \
    HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist \
    MALLOC_ARENA_MAX=2 \
    PATH="/opt/venv/bin:$PATH"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git ripgrep procps build-essential \
 && python -m venv /opt/venv \
 && /opt/venv/bin/pip install --upgrade pip

# Source tree (incl. the prebuilt web_dist) from the Node stage.
COPY --from=web /src /opt/hermes
WORKDIR /opt/hermes
RUN /opt/venv/bin/pip install -e ".[web,messaging]" \
 && apt-get purge -y --auto-remove build-essential \
 && rm -rf /var/lib/apt/lists/*

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. Attach at /opt/data
# via `railway volume add -m /opt/data`.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
