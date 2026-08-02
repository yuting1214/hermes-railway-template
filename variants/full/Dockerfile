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
#
# Bumping the pin is MANUAL and deliberate: see docs/upstream-changelog.md for what
# each release changed. For the republish rules (a bump must never alter the
# marketplace slug or the referral links) use the `railway-templates` skill.
#
# Pinned upstream release: v2026.7.30 == Hermes Agent v0.19.1 (2026-07-30).
ARG HERMES_REF=v2026.7.30
ARG HERMES_VERSION=0.19.1

# ---- Stage 1: build the dashboard frontend ----
FROM node:22-bookworm-slim AS web
ARG HERMES_REF
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${HERMES_REF}" https://github.com/nousresearch/hermes-agent.git . 2>/dev/null \
 || git clone --depth 1 https://github.com/nousresearch/hermes-agent.git .
# Drop the heavy Electron desktop workspace; build only the web dashboard.
# KEEP apps/shared: since ~v0.19.0 the web workspace imports `@hermes/shared`
# ("file:../apps/shared"), so a blanket `rm -rf apps` breaks `tsc -b` with
# "Cannot find module '@hermes/shared'". It's a tiny source-only package
# (exports .ts directly, no build step) and is pruned with the tree below.
# `npm run build` (web) = `tsc -b && vite build` → outputs to hermes_cli/web_dist.
RUN rm -rf apps/desktop apps/bootstrap-installer \
 && npm install --no-audit --no-fund \
 && npm run build --workspace web \
 && rm -rf node_modules web/node_modules ui-tui/node_modules .git

# ---- Stage 2: python runtime (dashboard + gateway) ----
# uv base image — `uv` ships in it, far faster installs/resolve than pip.
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim
ARG HERMES_REF
ARG HERMES_VERSION
ENV PYTHONUNBUFFERED=1 \
    UV_PYTHON_DOWNLOADS=0 \
    UV_NO_CACHE=1 \
    VIRTUAL_ENV=/opt/venv \
    HERMES_HOME=/opt/data \
    HOME=/opt/data \
    HERMES_WEB_DIST=/opt/hermes/hermes_cli/web_dist \
    MALLOC_ARENA_MAX=2 \
    PATH="/opt/venv/bin:$PATH" \
    HERMES_PINNED_REF=${HERMES_REF} \
    HERMES_PINNED_VERSION=${HERMES_VERSION}

# Patched SQLite + pinned tirith, folded into the SAME layer that already installs
# build-essential — separate builder stages would each pay for their own toolchain
# download and inflate cold-build time, which is what Railway deploys experience.
# Rationale for both is in docs/upstream-changelog.md; short version:
#   sqlite — bookworm 3.40.1 / trixie 3.46.1 both carry the WAL-reset corruption
#            bug, so Hermes silently falls back to journal_mode=DELETE on state.db
#            (which v0.19.0 made central). Needs >= 3.51.3; upstream compiles it
#            too. We build ONLY libsqlite3 to skip a second amalgamation compile.
#   tirith — otherwise self-downloads `latest` from a third-party repo at first
#            boot into the billed volume, SHA-256 only. Runtime off switch:
#            TIRITH_ENABLED=false.
ARG SQLITE_AUTOCONF_VERSION=3530400
ARG SQLITE_SHA256=0e9483900e92cd5de8fd48d16bf9200145a61f7fd5be542a5ac81d8a9516eb9c
ARG TIRITH_VERSION=v0.3.3
ARG TARGETARCH
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep procps build-essential; \
    \
    curl -fsSL --retry 3 --retry-all-errors --connect-timeout 15 --max-time 120 \
        -o /tmp/sqlite.tar.gz \
        "https://sqlite.org/2026/sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}.tar.gz"; \
    printf '%s  %s\n' "${SQLITE_SHA256}" /tmp/sqlite.tar.gz > /tmp/sqlite.sha256; \
    sha256sum -c /tmp/sqlite.sha256; \
    tar -xzf /tmp/sqlite.tar.gz -C /tmp; \
    cd "/tmp/sqlite-autoconf-${SQLITE_AUTOCONF_VERSION}"; \
    CFLAGS="-O2 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE \
        -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_MATH_FUNCTIONS \
        -DSQLITE_ENABLE_DBSTAT_VTAB -DSQLITE_ENABLE_PREUPDATE_HOOK \
        -DSQLITE_ENABLE_SESSION -DSQLITE_SECURE_DELETE \
        -DSQLITE_THREADSAFE=1 -DSQLITE_MAX_VARIABLE_NUMBER=250000" \
        ./configure --prefix=/usr/local --disable-static --disable-readline >/dev/null; \
    # 3.53's autoconf package dropped libtool/automake for autosetup: no
    # `libsqlite3.la` target, no `.libs/`. Build just the DLL; `install-dll` puts it
    # in /usr/local/lib and creates the libsqlite3.so / .so.0 symlinks, keeping the
    # public soname stable. `000-` wins the ld.so search order.
    make -j"$(nproc)" libsqlite3.so; \
    make install-dll install-headers; \
    printf '/usr/local/lib\n' > /etc/ld.so.conf.d/000-sqlite-fixed.conf; \
    ldconfig; \
    cd /; rm -rf /tmp/sqlite*; \
    \
    case "${TARGETARCH:-amd64}" in \
        amd64) tarch="x86_64" ;; \
        arm64) tarch="aarch64" ;; \
        *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    asset="tirith-${tarch}-unknown-linux-gnu.tar.gz"; \
    tbase="https://github.com/sheeki03/tirith/releases/download/${TIRITH_VERSION}"; \
    cd /tmp; \
    curl -fsSL --retry 3 --retry-all-errors -o "/tmp/${asset}" "${tbase}/${asset}"; \
    curl -fsSL --retry 3 --retry-all-errors -o /tmp/checksums.txt "${tbase}/checksums.txt"; \
    awk -v f="${asset}" '$2 == f { print $1 "  " f }' /tmp/checksums.txt > /tmp/want.sha256; \
    test -s /tmp/want.sha256; \
    sha256sum -c /tmp/want.sha256; \
    tar -xzf "/tmp/${asset}" -C /tmp; \
    find /tmp -type f -name tirith -exec cp {} /usr/local/bin/tirith \; ; \
    chmod +x /usr/local/bin/tirith; \
    /usr/local/bin/tirith --version; \
    cd /; rm -rf /tmp/tirith* /tmp/checksums.txt /tmp/want.sha256; \
    \
    uv venv /opt/venv; \
    /opt/venv/bin/python -c "import sqlite3, sys; \
v = sqlite3.sqlite_version_info; \
sys.exit(f'linked SQLite {sqlite3.sqlite_version} still has the WAL-reset bug') if v < (3, 51, 3) else None"

# Source tree (incl. the prebuilt web_dist) from the Node stage.
COPY --from=web /src /opt/hermes
WORKDIR /opt/hermes
RUN uv pip install -e ".[web,messaging]" \
 && apt-get purge -y --auto-remove build-essential \
 && rm -rf /var/lib/apt/lists/*

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Version tracking — which upstream release this image is built from. Inspect with
#   docker inspect --format '{{index .Config.Labels "com.nousresearch.hermes.release"}}' <img>
LABEL org.opencontainers.image.title="Hermes Agent (Full) — Railway template" \
      org.opencontainers.image.description="Hermes agent + the first-party Nous dashboard, built from source, ~300 MB RSS" \
      org.opencontainers.image.source="https://github.com/yuting1214/hermes-railway-template" \
      org.opencontainers.image.version="${HERMES_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      com.nousresearch.hermes.release="${HERMES_REF}" \
      com.nousresearch.hermes.version="${HERMES_VERSION}" \
      com.nousresearch.hermes.upstream="https://github.com/NousResearch/hermes-agent/releases/tag/${HERMES_REF}"

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. Attach at /opt/data
# via `railway volume add -m /opt/data`.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
