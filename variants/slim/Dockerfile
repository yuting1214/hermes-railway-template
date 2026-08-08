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

# Pinned upstream release: v2026.8.3 == Hermes Agent v0.20.0 (2026-08-03).
ARG HERMES_REF=v2026.8.3
ARG HERMES_VERSION=0.20.0
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

# ---- Stage 1b: bundled assets the wheel throws away -------------------------
# Upstream's setup.py refuses wheel builds precisely because "the wheel would ship
# without bundled assets (locales, skills, optional-mcps, web_dist, tui_dist,
# **plugin manifests**)". We force that wheel anyway (HERMES_NIX_BUILD=1, to avoid
# keeping the ~208 MB source checkout an editable install needs), so we must put
# those assets back or they are silently missing.
#
# This is not theoretical: without the plugin manifests, `plugins/platforms/telegram`
# ships its 472 KB adapter.py but no plugin.yaml, the loader finds nothing to scan
# ("No plugins installed"), _create_adapter() has no built-in telegram branch in
# 0.19.x, and the gateway logs "No adapter available for telegram" — i.e. the
# template's headline feature is dead while the container looks perfectly healthy.
#
# Fetch the tag tarball (no git, no 208 MB checkout) and keep only the asset trees:
# plugins 8.5 MB / skills 7.2 MB / locales / optional-mcps.
FROM debian:12-slim AS assets
ARG HERMES_REF
RUN set -eux; \
    apt-get -o Acquire::Retries=3 update; \
    apt-get -o Acquire::Retries=3 install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /assets; \
    curl -fsSL --retry 3 --retry-all-errors --connect-timeout 15 --max-time 300 \
        "https://codeload.github.com/NousResearch/hermes-agent/tar.gz/refs/tags/${HERMES_REF}" \
      | tar -xz -C /assets --strip-components=1 --wildcards \
            '*/plugins/*' '*/skills/*' '*/locales/*' '*/optional-mcps/*'; \
    test -d /assets/plugins; \
    test -d /assets/skills; \
    # A wheel with zero plugin manifests is exactly the bug this stage exists for.
    n="$(find /assets/plugins -name plugin.yaml | wc -l)"; \
    echo "bundled plugin manifests recovered: ${n}"; \
    test "${n}" -gt 0; \
    test -f /assets/plugins/platforms/telegram/plugin.yaml

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
    HERMES_PINNED_VERSION=${HERMES_VERSION} \
    HERMES_BUNDLED_PLUGINS=/opt/hermes-assets/plugins \
    HERMES_BUNDLED_SKILLS=/opt/hermes-assets/skills

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
# thing it does. It also avoids the "refusing to run the gateway as root inside the
# official Docker image" guard. If a future bump makes this stop working the BUILD
# fails loudly — no broken image can reach deployers.
#
# CORRECTION (2026-08-08): this used to claim the wheel saved 44 MiB RSS (87 vs 131
# editable). That comparison was invalid — the 87 MiB was a CRIPPLED install with
# zero plugins loaded, because the wheel had silently dropped every plugin manifest.
# With the assets restored below, the wheel measures ~130 MiB, i.e. the same as
# editable. The only remaining reason to prefer the wheel is IMAGE SIZE (772 MB vs
# ~950 MB, since editable must keep the source tree). If that stops being worth the
# maintenance, switch to `uv pip install -e` and delete the assets stage entirely.
#
# This runs while the `deps` stage compiles SQLite in parallel.
# xz-utils is NOT for this build — it is for the runtime escape hatch below. Node's
# release tarball is `.tar.xz`, and without `xz` upstream's installer aborts with
# "tar (child): xz: Cannot exec: No such file or directory". xz-utils + the bundled
# install.sh measured **+6 MB** on the final image (734 -> 740 MB).
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep procps xz-utils build-essential; \
    uv venv /opt/venv; \
    HERMES_NIX_BUILD=1 uv pip install \
        "hermes-agent[${HERMES_EXTRAS}] @ git+https://github.com/nousresearch/hermes-agent.git@${HERMES_REF}"; \
    \
    # Restore upstream's lazy-dependency escape hatch. `hermes_cli.dep_ensure` treats
    # node/browser/ffmpeg as installable-on-demand and shells out to the repo's
    # scripts/install.sh — but a NON-editable install (which we choose: 87 MiB RSS vs
    # 131 MiB editable) never ships that script, so _find_install_script() returns None
    # and the agent dead-ends with "no install script was found" instead of offering to
    # install. Fetch it at the SAME pinned ref so script and code always match.
    # Nothing is installed at build time: this only runs if a tool asks for node at
    # runtime, and it installs into $HERMES_HOME (the Railway volume, ~200 MB for Node)
    # so it survives redeploys. A local browser is still NOT supported here — Chromium
    # needs ~25 X/GTK/NSS libraries this image deliberately omits; use the hosted
    # browsing extras (exa / firecrawl / parallel-web) instead. See TEMPLATE.md.
    site="$(/opt/venv/bin/python -c 'import hermes_cli, os; print(os.path.dirname(hermes_cli.__file__))')"; \
    mkdir -p "${site}/scripts"; \
    curl -fsSL --retry 3 --retry-all-errors --connect-timeout 15 --max-time 120 \
        -o "${site}/scripts/install.sh" \
        "https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_REF}/scripts/install.sh"; \
    chmod +x "${site}/scripts/install.sh"; \
    /opt/venv/bin/python -c "from hermes_cli.dep_ensure import _find_install_script; p, s = _find_install_script(); assert p is not None, 'lazy-dep escape hatch still broken'; print(f'lazy-dep installer: {p} ({s})')"; \
    \
    apt-get purge -y --auto-remove build-essential; \
    rm -rf /var/lib/apt/lists/*

# Put back what the wheel dropped. HERMES_BUNDLED_PLUGINS / HERMES_BUNDLED_SKILLS are
# upstream's OWN packaging hooks (their docstring: "used by Homebrew and Nix
# packaging"), so relocating these trees is the supported packager path, not a patch.
# locales/ and optional-mcps/ have no env hook — they resolve relative to the package
# root, which for this install is site-packages/, the same repo-root-relative layout a
# source checkout would present.
COPY --from=assets /assets/plugins        /opt/hermes-assets/plugins
COPY --from=assets /assets/skills         /opt/hermes-assets/skills
COPY --from=assets /assets/locales        /opt/venv/lib/python3.12/site-packages/locales
COPY --from=assets /assets/optional-mcps  /opt/venv/lib/python3.12/site-packages/optional-mcps

# ASSERTION — the guard that was missing on 2026-08-02. Back then the wheel silently
# shipped a template with no messaging adapters at all: containers booted, deploys
# reported healthy, `hermes -z` answered, and Telegram/Discord/Slack were simply gone.
# A stripped asset tree must fail the BUILD, never reach a deployer.
RUN set -eux; \
    export HERMES_HOME=/tmp/plugincheck HOME=/tmp/plugincheck; \
    mkdir -p "$HERMES_HOME"; \
    /opt/venv/bin/hermes plugins list > /tmp/plugins.txt 2>&1 || true; \
    if ! grep -q telegram /tmp/plugins.txt; then \
        echo "FATAL: telegram plugin not registered — bundled assets are missing"; \
        cat /tmp/plugins.txt; exit 1; \
    fi; \
    echo "--- bundled plugin discovery ---"; cat /tmp/plugins.txt; \
    rm -rf /tmp/plugincheck /tmp/plugins.txt

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
      org.opencontainers.image.description="Headless Hermes agent: CLI + always-on messaging gateway, ~160 MB RSS" \
      org.opencontainers.image.source="https://github.com/yuting1214/hermes-railway-template" \
      org.opencontainers.image.version="${HERMES_VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      com.nousresearch.hermes.release="${HERMES_REF}" \
      com.nousresearch.hermes.version="${HERMES_VERSION}" \
      com.nousresearch.hermes.upstream="https://github.com/NousResearch/hermes-agent/releases/tag/${HERMES_REF}"

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. The persistent
# volume is attached out-of-band: `railway volume add -m /data` (see docs).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
