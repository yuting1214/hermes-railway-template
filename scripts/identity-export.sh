#!/usr/bin/env bash
#
# identity-export.sh — LEAN, SELECTIVE export of a Hermes agent's identity from a
# remote Railway container.
#
# Why this exists: `hermes profile export` stages the ENTIRE HERMES_HOME (tool
# virtualenvs, the 100+ MB state.db, caches) into /tmp before tarring — it can
# balloon to multiple GB and even crash (`--clone-all` → RecursionError on venv
# symlinks, upstream #11560). This tars ONLY what you select, so it stays tiny.
#
# DEFAULT (always included) — the agent's portable identity:
#   memories/     curated memory: MEMORY.md (agent notes) + USER.md (about you)
#   SOUL.md       persona / crafted system prompt
#   config.yaml   model + harness + allowlist + cron settings
#   skills/       cultivated skills
#   cron/         scheduled jobs
#
# OPT-IN flags:
#   --auth        all credentials/secrets in one bundle:
#                   auth.json (Codex/provider OAuth) + google_* + pairing/
#   --state       state.db*  — full conversation history (LARGE; the thing the
#                 lean export deliberately omits — only pull it if you truly want
#                 the new agent to inherit the old transcripts)
#   --extra "a b" any extra space-separated paths under HERMES_HOME
#
# Usage:
#   SERVICE=hermes REMOTE_HOME=/data ./identity-export.sh [--auth] [--state] [-o out.tgz]
#   SERVICE=hermes ./identity-export.sh --auth          # identity + crons + all secrets
#
# Run from a directory linked to the Railway project.
#
set -euo pipefail
SERVICE="${SERVICE:-hermes}"
REMOTE_HOME="${REMOTE_HOME:-/data}"     # /data (slim) | /opt/data (full)
OUT=""

# Default = identity + cron. Flags append to this list.
PATHS=(memories SOUL.md config.yaml skills cron)

while [ $# -gt 0 ]; do
  case "$1" in
    --auth)  PATHS+=(auth.json google_calendar_auth_state.json google_calendar_client.json google_service_account.json pairing) ;;
    --state) PATHS+=(state.db state.db-wal state.db-shm) ;;
    --extra) shift; read -r -a _x <<<"${1:-}"; PATHS+=("${_x[@]}") ;;
    -o|--output) shift; OUT="${1:-}" ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

TS="$(date -u +%Y%m%d-%H%M%S)"
OUT="${OUT:-./hermes-identity-${SERVICE}-${TS}.tar.gz}"
REMOTE_TAR="/tmp/hermes-identity-export.tar.gz"

# CR-tolerant base64 decode (railway ssh emits CRLF).
b64decode() { python3 -c 'import base64,sys;sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))'; }

# 1) Keep only SELECTED paths that actually exist on the remote (graceful skip).
#    `ls -1d <full paths>` is one space-free command → safe over railway ssh; -1
#    forces one-path-per-line (the pty otherwise prints columns).
FULL=(); for p in "${PATHS[@]}"; do FULL+=("$REMOTE_HOME/$p"); done
echo "Selecting from $SERVICE:$REMOTE_HOME → ${PATHS[*]}"
EXISTING="$(railway ssh -s "$SERVICE" -- ls -1d "${FULL[@]}" 2>/dev/null | tr -d '\r' | sed "s#^$REMOTE_HOME/##" | grep -v '^[[:space:]]*$' || true)"
if [ -z "$EXISTING" ]; then echo "ERROR: none of the selected paths exist" >&2; exit 1; fi
echo "Including: $(echo "$EXISTING" | tr '\n' ' ')"

# 2) Tar ONLY those paths on the remote (no HERMES_HOME staging → stays tiny).
#    $EXISTING is intentionally unquoted: each line is one space-free relative path.
# shellcheck disable=SC2086
railway ssh -s "$SERVICE" -- tar czf "$REMOTE_TAR" -C "$REMOTE_HOME" $EXISTING

# 3) Pull it down (base64 single cmd → local decode), validate, clean remote /tmp.
railway ssh -s "$SERVICE" -- base64 "$REMOTE_TAR" | b64decode > "$OUT"
railway ssh -s "$SERVICE" -- rm -f "$REMOTE_TAR" >/dev/null 2>&1 || true
tar tzf "$OUT" >/dev/null 2>&1 || { echo "ERROR: invalid tarball" >&2; exit 1; }

echo "✓ exported $(wc -c < "$OUT" | tr -d ' ') bytes → $OUT"
echo "  top-level:"; tar tzf "$OUT" | awk -F/ '{print $1}' | sort -u | sed 's/^/    /'
