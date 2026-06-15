#!/usr/bin/env bash
#
# onboard-codex.sh — Codex (ChatGPT subscription) login via the DEVICE-
# AUTHORIZATION flow, run inside the container over an interactive `railway ssh`
# shell.
#
# Why interactive (not automated): `railway ssh` mangles complex remote command
# strings and can't reliably drive tmux over the wire, so we just drop you into a
# shell and you run one command. The device flow prints a URL + code and needs NO
# port-forwarding, so it completes cleanly from here.
#
# Run from a directory linked to the Railway project.
#
# Usage:
#   SERVICE=hermes [PROVIDER=openai-codex] ./onboard-codex.sh
#
set -euo pipefail
SERVICE="${SERVICE:-hermes}"
PROVIDER="${PROVIDER:-openai-codex}"

cat <<TXT
Opening an interactive shell on '$SERVICE'. Once you're in, run:

    hermes login --provider $PROVIDER --no-browser

Then:
  • open the printed verification URL on this Mac, sign in with ChatGPT,
    and enter the code shown in the shell;
  • pick the Codex model:   hermes model        (choose the openai-codex entry)
  • test it:                hermes -z 'reply: CODEX_OK'
  • type 'exit' to leave.

Tokens are written to \$HERMES_HOME/auth.json on the volume, so they persist
across redeploys.

Connecting...
TXT
exec railway ssh -s "$SERVICE"
