# syntax=docker/dockerfile:1
#
# Hermes-Agent — SLIM variant (CLI + messaging gateway only, no Node/Playwright).
# Smallest RAM/image; driven over `railway ssh`, answers messaging 24/7
# via `hermes gateway run`. Data lives on a Railway volume at /data (HERMES_HOME).
#
# Build args:
#   HERMES_REF     git ref to install. Defaults to a pinned CalVer release tag
#                  (see ARG below) for reproducible builds — upstream tags are
#                  date-versioned (e.g. v2026.7.30), NOT the v0.x package version.
#                  Override with another tag/sha, or `main` for always-latest.
#   HERMES_EXTRAS  uv/pip extras (default: messaging → Telegram/Discord/Slack
#                  adapters eager-installed so the bot needs no runtime install).
#
# Bumping the pin is MANUAL and deliberate: see docs/upstream-changelog.md for what
# each release changed. For the republish rules (a bump must never alter the
# marketplace slug or the referral links) use the `railway-templates` skill.

# Pinned upstream release: v2026.7.30 == Hermes Agent v0.19.1 (2026-07-30).
ARG HERMES_REF=v2026.7.30
ARG HERMES_VERSION=0.19.1
ARG HERMES_EXTRAS=messaging
# Patched SQLite — Hermes requires >= 3.51.3; see the `deps` stage.
ARG SQLITE_AUTOCONF_VERSION=3530400
ARG SQLITE_SHA256=0e9483900e92cd5de8fd48d16bf9200145a61f7fd5be542a5ac81d8a9516eb9c
# Hermes' exec-safety scanner, pinned instead of self-downloaded at first boot.
ARG TIRITH_VERSION=v0.3.3

# ---- Stage 1: sidecar deps -------------------------------------------------
# Deliberately a SEPARATE stage: BuildKit runs it CONCURRENTLY with the runtime
# stage below, and the runtime stage only blocks on it at the `COPY` — which is
# placed *after* the slow `uv pip install`. The SQLite compile therefore hides
# almost entirely behind the Hermes install instead of adding to it.
# Toolchain is `gcc make libc6-dev`, not build-essential: we compile one C file,
# so g++/dpkg-dev/etc. are dead weight on the critical path.
FROM debian:12-slim AS deps
ARG SQLITE_AUTOCONF_VERSION
ARG SQLITE_SHA256
ARG TIRITH_VERSION
ARG TARGETARCH
RUN set -eux; \
    apt-get -o Acquire::Retries=3 update; \
    apt-get -o Acquire::Retries=3 install -y --no-install-recommends \
        ca-certificates curl gcc make libc6-dev; \
    rm -rf /var/lib/apt/lists/*; \
    \
    # --- patched SQLite -----------------------------------------------------
    # Bookworm ships 3.40.1 and trixie only 3.46.1 — both carry the WAL-reset
    # corruption bug, so Hermes refuses WAL and silently falls back to
    # journal_mode=DELETE. That bites since v0.19.0, which moved gateway session
    # metadata, the routing index and the durable delivery ledger INTO state.db.
    # A base-image swap does NOT fix this; upstream's own Dockerfile compiles
    # SQLite for the same reason. https://sqlite.org/wal.html#walresetbug
    # 3.53's package uses autosetup (no libtool): build just the DLL, then
    # `install-dll` stages it plus its .so/.so.0 symlinks under /out/lib.
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
        ./configure --prefix=/out --disable-static --disable-readline >/dev/null; \
    make -j"$(nproc)" libsqlite3.so; \
    make install-dll; \
    \
    # --- pinned tirith ------------------------------------------------------
    # Left alone, Hermes downloads `latest` from a THIRD-PARTY repo at first boot
    # into $HERMES_HOME/bin (the billed Railway volume) with SHA-256 verification
    # only (cosign isn't present). Pin + verify it here: no first-boot egress, no
    # volume write. `shutil.which("tirith")` finds it, so auto-install never fires.
    # Runtime override: TIRITH_ENABLED=false disables the scanner entirely.
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
    mkdir -p /out/bin; \
    find /tmp -type f -name tirith -exec cp {} /out/bin/tirith \; ; \
    chmod +x /out/bin/tirith; \
    /out/bin/tirith --version

# ---- Stage 2: runtime -------------------------------------------------------
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS base
ARG HERMES_REF
ARG HERMES_VERSION
ARG HERMES_EXTRAS

ENV PYTHONUNBUFFERED=1 \
    UV_PYTHON_DOWNLOADS=0 \
    UV_NO_CACHE=1 \
    VIRTUAL_ENV=/opt/venv \
    HERMES_HOME=/data \
    HOME=/data \
    MALLOC_ARENA_MAX=2 \
    PATH="/opt/venv/bin:$PATH" \
    HERMES_PINNED_REF=${HERMES_REF} \
    HERMES_PINNED_VERSION=${HERMES_VERSION}

# Runtime deps only: ripgrep (Hermes file-search tool), git, ca-certificates/curl
# (TLS), procps (ps — used by gateway status). build tools are added then removed
# in one layer so any source-only wheels resolve without bloating the final image.
# (No tmux: `railway ssh --session` provisions it on demand when you want one.)
# `uv` ships in the base image — far faster installs/resolve than pip.
#
# HERMES_NIX_BUILD=1: since v2026.7.30 upstream's setup.py hard-refuses to build a
# wheel/sdist ("Hermes is distributed via the shell installer, Docker image, or
# Nix"), which breaks a plain `uv pip install … @ git+…`. This is upstream's own
# escape hatch for their Nix derivation and skipping that policy guard is the ONLY
# thing it does — the build is identical to what v2026.7.20 produced. Preferred
# over an editable install, which measured 131 MiB RSS vs 87 MiB here (Railway
# bills RAM) and additionally trips the "refusing to run the gateway as root
# inside the official Docker image" guard. If a future bump makes this stop
# working the BUILD fails loudly — no broken image can reach deployers.
#
# This runs while the `deps` stage compiles SQLite in parallel.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep procps build-essential; \
    uv venv /opt/venv; \
    HERMES_NIX_BUILD=1 uv pip install \
        "hermes-agent[${HERMES_EXTRAS}] @ git+https://github.com/nousresearch/hermes-agent.git@${HERMES_REF}"; \
    apt-get purge -y --auto-remove build-essential; \
    rm -rf /var/lib/apt/lists/*

# Only NOW do we block on the sidecar stage. Keeping the public soname stable lets
# both the stock interpreter and the venv resolve the replacement with no
# import-path changes; `000-` wins the ld.so search order.
COPY --from=deps /out/lib/ /usr/local/lib/
COPY --from=deps /out/bin/tirith /usr/local/bin/tirith
RUN set -eux; \
    printf '/usr/local/lib\n' > /etc/ld.so.conf.d/000-sqlite-fixed.conf; \
    ldconfig; \
    /opt/venv/bin/python -c "import sqlite3, sys; \
v = sqlite3.sqlite_version_info; \
sys.exit(f'linked SQLite {sqlite3.sqlite_version} still has the WAL-reset bug') if v < (3, 51, 3) else None"; \
    tirith --version

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Version tracking — which upstream release this image is built from. Inspect with
#   docker inspect --format '{{index .Config.Labels "com.nousresearch.hermes.release"}}' <img>
LABEL org.opencontainers.image.title="Hermes Agent (Slim) — Railway template" \
      org.opencontainers.image.description="Headless Hermes agent: CLI + always-on messaging gateway, ~90 MB RSS" \
      org.opencontainers.image.source="https://github.com/yuting1214/hermes-railway-template" \
      org.opencontainers.image.version="${HERMES_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      com.nousresearch.hermes.release="${HERMES_REF}" \
      com.nousresearch.hermes.version="${HERMES_VERSION}" \
      com.nousresearch.hermes.upstream="https://github.com/NousResearch/hermes-agent/releases/tag/${HERMES_REF}"

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. The persistent
# volume is attached out-of-band: `railway volume add -m /data` (see docs).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
