#!/usr/bin/env bash
#
# backup-pull.sh — export a Hermes PROFILE on the remote service and pull it to
# this machine, then optionally ship it off-box. The profile tarball is your
# portable agent identity: SOUL.md (prompt), skills/, config.yaml (harness/loop),
# memories/, cron/. Secrets (.env / auth.json) are intentionally EXCLUDED by
# `hermes profile export`.
#
# Run this from a directory linked to the Railway project (where you ran
# `railway init`/`railway link`).
#
# Transport notes (verified against railway CLI 4.30.2):
#   * `railway ssh -- <cmd>` only handles a SINGLE simple command reliably —
#     complex `sh -c "... | ... > ..."` strings get mangled, and stdin piping
#     INTO the container hangs. So each remote step is one plain command.
#   * railway ssh converts output to CRLF, so we decode CR-tolerantly (python3).
#
# Usage:
#   SERVICE=hermes PROFILE=default SINK=none ./backup-pull.sh
#   SINK=git GIT_DIR=~/hermes-backups ./backup-pull.sh
#   SINK=r2  R2_BUCKET=my-bucket R2_ENDPOINT=https://<acct>.r2.cloudflarestorage.com ./backup-pull.sh
#
# For R2, AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY must be in the env (never
# hardcode — read them from your .env), per the cloudflare skill's convention.
#
set -euo pipefail
SERVICE="${SERVICE:-hermes}"
PROFILE="${PROFILE:-default}"
SINK="${SINK:-none}"
TS="$(date -u +%Y%m%d-%H%M%S)"
OUT="${OUT:-./${PROFILE}-${TS}.tar.gz}"
REMOTE="/tmp/${PROFILE}-export.tar.gz"

# CR-tolerant base64 decode (handles railway ssh's CRLF; works on macOS + Linux).
b64decode() { python3 -c 'import base64,sys; sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))'; }

echo "Exporting profile '$PROFILE' on '$SERVICE' ..."
railway ssh -s "$SERVICE" -- hermes profile export "$PROFILE" -o "$REMOTE"

echo "Streaming down -> $OUT"
railway ssh -s "$SERVICE" -- base64 "$REMOTE" | b64decode > "$OUT"
echo "  pulled $(wc -c < "$OUT") bytes"
tar tzf "$OUT" >/dev/null 2>&1 && echo "  tarball OK" || { echo "  ERROR: not a valid tar.gz" >&2; exit 1; }
railway ssh -s "$SERVICE" -- rm -f "$REMOTE" >/dev/null 2>&1 || true

case "$SINK" in
  git)
    : "${GIT_DIR:?set GIT_DIR to a local clone of your PRIVATE backup repo}"
    cp "$OUT" "$GIT_DIR/"
    ( cd "$GIT_DIR" && git add -A && git commit -m "backup($PROFILE): $TS" && git push )
    echo "  pushed to git: $GIT_DIR"
    ;;
  r2)
    : "${R2_BUCKET:?set R2_BUCKET}" "${R2_ENDPOINT:?set R2_ENDPOINT}"
    aws s3 cp "$OUT" "s3://${R2_BUCKET}/${R2_PREFIX:-hermes}/$(basename "$OUT")" \
      --endpoint-url "$R2_ENDPOINT"
    echo "  uploaded to R2: ${R2_BUCKET}/${R2_PREFIX:-hermes}/"
    ;;
  none) ;;
  *) echo "unknown SINK=$SINK (use none|git|r2)" >&2; exit 1 ;;
esac

echo "Done."
