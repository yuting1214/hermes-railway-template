#!/usr/bin/env bash
#
# onboard-codex.sh — Codex (ChatGPT subscription) auth via the DEVICE-AUTHORIZATION
# flow, driven over `railway ssh`. The command prints a URL + short code, you
# authorize in any browser, and it polls to completion — no port-forwarding, no
# token copying, so it works cleanly over `railway ssh` (a single simple command).
#
# NOTE: these images build from upstream `@main`, where the old `hermes login` was
# removed — the current command is `hermes auth add`.
#
# Run from a directory linked to the Railway project.
#
# Usage:
#   SERVICE=hermes [PROVIDER=openai-codex] [MODEL=openai-codex/gpt-5.4] ./onboard-codex.sh
#
set -euo pipefail
SERVICE="${SERVICE:-hermes}"
PROVIDER="${PROVIDER:-openai-codex}"
MODEL="${MODEL:-openai-codex/gpt-5.4}"

cat <<TXT
Starting Codex device-flow login on '$SERVICE'.
When the URL + code print below:
  1. open the URL on this Mac,
  2. enter the code and sign in with ChatGPT.
This command finishes on its own once you approve (it polls).

TXT

# Blocks while polling; prints "Added openai-codex OAuth credential" on success.
railway ssh -s "$SERVICE" -- hermes auth add "$PROVIDER" --type oauth --no-browser

echo
echo "Setting model = ${MODEL} ..."
railway ssh -s "$SERVICE" -- hermes config set model "$MODEL"

echo "Verifying ..."
railway ssh -s "$SERVICE" -- hermes auth status "$PROVIDER"
railway ssh -s "$SERVICE" -- hermes -z ping      # → pong

echo
echo "Done. auth.json + model are on the volume (persist across redeploys)."
