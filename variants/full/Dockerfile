# syntax=docker/dockerfile:1
#
# Hermes-Agent — FULL / UI variant.
# Based on the OFFICIAL Hermes-team image (ghcr.io/nousresearch/hermes), which
# already ships s6-overlay supervision, the gateway, the Node TUI, and the
# first-party `hermes dashboard` web UI. This is the legitimate Hermes UI —
# NOT the third-party UI bundled by the marketplace template.
#
# We add only:
#   - tmux                (session persistence for `railway ssh`)
#   - a thin entrypoint   (binds the dashboard to 0.0.0.0:$PORT and mirrors
#                          Railway secrets into the volume's .env)
#
# IMPORTANT: the image's s6 services hardcode HERMES_HOME=/opt/data, so the
# Railway volume MUST be mounted at /opt/data (not /data).
FROM ghcr.io/nousresearch/hermes:latest

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends tmux \
 && rm -rf /var/lib/apt/lists/*

# Enable the supervised first-party dashboard. Host/port are set per-deploy by
# the entrypoint ($PORT is injected by Railway). Dashboard is OAuth-protected by
# default; set HERMES_DASHBOARD_INSECURE=1 only if you front it with your own auth.
ENV HERMES_DASHBOARD=1 \
    HERMES_HOME=/opt/data

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# NOTE: no Docker `VOLUME` instruction — Railway rejects it. Attach the volume
# out-of-band at /opt/data: `railway volume add -m /opt/data` (see docs).
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
CMD ["gateway", "run"]
