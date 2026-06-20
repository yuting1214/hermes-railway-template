#!/usr/bin/env bash
#
# identity-import.sh — clone a Hermes agent's identity from one Railway service to
# another *in the same project*, over Railway's PRIVATE network (the data never
# leaves Railway; no external host, no public paste).
#
# It's the receiving half of identity-export.sh. Same lean selection: tars only
# the chosen paths on the source (no HERMES_HOME staging → tiny), serves them
# briefly over the private network, and the target curl's + extracts them.
#
# Why a relay (not scp/stdin): `railway ssh` can't stream a file *into* a
# container (stdin hangs) and mangles complex `sh -c`. But a single `curl <url>`
# on the target works, and two services in one project reach each other at
# <service>.railway.internal — so we serve from SRC and fetch from DST.
#
# DEFAULT selection (always): memories/ SOUL.md config.yaml skills/ cron/
# OPT-IN:
#   --auth         auth.json + google_* + pairing/   (SECRET — copies the login)
#   --state        state.db*                          (full conversation history)
#   --extra "a b"  arbitrary extra paths under HERMES_HOME
#   --restart      redeploy DST afterwards so its gateway adopts the new config
#
# Usage:
#   SRC=hermes DST=hermes-clone ./identity-import.sh                 # identity only, no auth
#   SRC=hermes DST=hermes-clone SRC_HOME=/data DST_HOME=/opt/data ./identity-import.sh --auth
#
# Run from a directory linked to the Railway project.
#
set -euo pipefail
SRC="${SRC:-hermes}"
DST="${DST:?set DST=<target service> (e.g. hermes-clone)}"
SRC_HOME="${SRC_HOME:-/data}"      # source HERMES_HOME (/data slim, /opt/data full)
DST_HOME="${DST_HOME:-/data}"      # target HERMES_HOME
PORT="${PORT:-8099}"
RESTART=0

PATHS=(memories SOUL.md config.yaml skills cron)
while [ $# -gt 0 ]; do
  case "$1" in
    --auth)    PATHS+=(auth.json google_calendar_auth_state.json google_calendar_client.json google_service_account.json pairing) ;;
    --state)   PATHS+=(state.db state.db-wal state.db-shm) ;;
    --extra)   shift; read -r -a _x <<<"${1:-}"; PATHS+=("${_x[@]}") ;;
    --restart) RESTART=1 ;;
    -h|--help) sed -n '2,33p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done
[ "$SRC" = "$DST" ] && { echo "SRC and DST must differ" >&2; exit 1; }

SEED="/tmp/hermes-seed-clone.tar.gz"

# Resolve the source's private domain (e.g. hermes.railway.internal).
SRC_DOMAIN="$(railway ssh -s "$SRC" -- printenv RAILWAY_PRIVATE_DOMAIN 2>/dev/null | tr -d '\r' | grep -m1 . || true)"
[ -n "$SRC_DOMAIN" ] || { echo "could not resolve $SRC private domain" >&2; exit 1; }

# Cleanup on exit: stop the relay + remove temp files on both ends.
cleanup() {
  railway ssh -s "$SRC" -- pkill -f http.server >/dev/null 2>&1 || true
  kill "${RELAY_PID:-0}" 2>/dev/null || true
  railway ssh -s "$SRC" -- rm -f "$SEED" >/dev/null 2>&1 || true
  railway ssh -s "$DST" -- rm -f "$SEED" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# 1) Keep only selected paths that exist on SRC (ls -1d = one space-free token/line).
FULL=(); for p in "${PATHS[@]}"; do FULL+=("$SRC_HOME/$p"); done
EXISTING="$(railway ssh -s "$SRC" -- ls -1d "${FULL[@]}" 2>/dev/null | tr -d '\r' | sed "s#^$SRC_HOME/##" | grep -v '^[[:space:]]*$' || true)"
[ -n "$EXISTING" ] || { echo "no selected paths exist on $SRC:$SRC_HOME" >&2; exit 1; }
echo "Cloning $SRC:$SRC_HOME → $DST:$DST_HOME"
echo "  paths: $(echo "$EXISTING" | tr '\n' ' ')"

# 2) Tar only those paths on SRC (no staging → stays tiny).
# shellcheck disable=SC2086
railway ssh -s "$SRC" -- tar czf "$SEED" -C "$SRC_HOME" $EXISTING

# 3) Serve over the private network (background), then fetch + extract on DST.
railway ssh -s "$SRC" -- pkill -f http.server >/dev/null 2>&1 || true   # clear stale server
railway ssh -s "$SRC" -- python3 -m http.server "$PORT" --bind :: --directory /tmp &
RELAY_PID=$!
sleep 6
railway ssh -s "$DST" -- curl -fsS --max-time 60 "http://$SRC_DOMAIN:$PORT/$(basename "$SEED")" -o "$SEED"
railway ssh -s "$DST" -- tar xzf "$SEED" -C "$DST_HOME"

# 4) Verify + optional restart.
echo "=== clone identity on $DST ==="
railway ssh -s "$DST" -- hermes profile show default 2>&1 | head -10
[ "$RESTART" = 1 ] && { echo "restarting $DST..."; railway redeploy -s "$DST" -y >/dev/null 2>&1 || true; }

echo "✓ cloned $SRC → $DST. NOTE: auth$([ "${PATHS[*]}" = "${PATHS[*]/auth.json/}" ] && echo ' NOT' ) copied; set Codex/Telegram on $DST as needed."
