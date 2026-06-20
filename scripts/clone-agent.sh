#!/usr/bin/env bash
#
# clone-agent.sh — reproducibly clone a RUNNING Hermes agent into a NEW Railway
# service in the SAME project. One command: create the service + volume, deploy
# the slim image, transfer the lean identity over Railway's private network,
# restart, and verify the identity byte-for-byte. Leaves a supervised gateway
# ready for you to add auth.
#
# It composes the building blocks (identity-import.sh) plus the railway service
# bring-up that the hermes-clone skill documents. Lean by design: NO state.db,
# venvs, or caches (so it never bloats /tmp the way `hermes profile export` does).
#
# Usage:
#   SRC=hermes NEW=hermes-clone2 ./clone-agent.sh           # identity only (no auth)
#   SRC=hermes NEW=hermes-clone2 ./clone-agent.sh --auth    # also clone credentials
#   SRC=hermes NEW=hermes-clone2 ./clone-agent.sh --auth --state   # full mirror
#
# Env:
#   SRC        source service              (default: hermes)
#   NEW        new service name            (REQUIRED)
#   SRC_HOME   source HERMES_HOME          (default: /data; /opt/data for full)
#   NEW_HOME   new HERMES_HOME             (default: /data)
#   VARIANT    slim|full build context     (default: slim)
#   WAIT       seconds to wait for first boot (default: 90)
#
# Extra flags (--auth/--state/--extra "…") are forwarded to identity-import.sh.
# Prereqs: railway CLI logged in + linked to the target project; run from anywhere
# inside the hermes-agent repo (paths are resolved from this script's location).
#
set -euo pipefail
SRC="${SRC:-hermes}"
NEW="${NEW:?set NEW=<new service name>}"
SRC_HOME="${SRC_HOME:-/data}"
NEW_HOME="${NEW_HOME:-/data}"
VARIANT="${VARIANT:-slim}"
WAIT="${WAIT:-90}"
PASS_FLAGS=("$@")
[ "$SRC" = "$NEW" ] && { echo "SRC and NEW must differ" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"
VARIANT_DIR="$REPO/variants/$VARIANT"
[ -f "$VARIANT_DIR/Dockerfile" ] || { echo "no Dockerfile at $VARIANT_DIR" >&2; exit 1; }

echo "== [1/5] create service '$NEW' + volume at $NEW_HOME =="
railway add --service "$NEW" 2>&1 | tail -2 || true
railway volume add -m "$NEW_HOME" 2>&1 | tail -2 || true   # attaches to the just-linked service
railway variable set 'MALLOC_ARENA_MAX=2' -s "$NEW" --skip-deploys >/dev/null 2>&1 || true

echo "== [2/5] deploy '$VARIANT' image to '$NEW' =="
( cd "$VARIANT_DIR" && railway up -s "$NEW" -d ) 2>&1 | tail -3
echo "   waiting ${WAIT}s for first boot…"; sleep "$WAIT"

echo "== [3/5] clone identity $SRC → $NEW (lean, private network) =="
SRC="$SRC" DST="$NEW" SRC_HOME="$SRC_HOME" DST_HOME="$NEW_HOME" \
  bash "$SCRIPT_DIR/identity-import.sh" "${PASS_FLAGS[@]}"

echo "== [4/5] restart so '$NEW' adopts the cloned config =="
railway redeploy -s "$NEW" -y >/dev/null 2>&1 || true
sleep 30

echo "== [5/5] verify identity matches '$SRC' (md5) =="
ok=1
for f in SOUL.md config.yaml memories/MEMORY.md memories/USER.md; do
  a="$(railway ssh -s "$SRC" -- md5sum "$SRC_HOME/$f" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
  b="$(railway ssh -s "$NEW" -- md5sum "$NEW_HOME/$f" 2>/dev/null | tr -d '\r' | awk '{print $1}')"
  if [ -n "$a" ] && [ "$a" = "$b" ]; then echo "   ✓ $f  $a"; else echo "   ✗ $f  ($a vs $b)"; ok=0; fi
done
[ "$ok" = 1 ] && echo "   → identity verified byte-for-byte" || echo "   → MISMATCH (investigate before relying on the clone)"

auth_note=', NO auth (set it below)'
case " ${PASS_FLAGS[*]} " in *" --auth "*) auth_note=' incl. auth';; esac
cat <<TXT

✓ Clone '$NEW' created from '$SRC'${auth_note}.

Finish setup on '$NEW':
  • Codex:    railway ssh -s $NEW -- hermes auth add openai-codex --type oauth --no-browser
  • Telegram: use a NEW BotFather token (NOT $SRC's, or Telegram returns 409):
              railway ssh -s $NEW            # then inside:  hermes gateway setup
              railway redeploy -s $NEW -y    # hardened entrypoint auto-starts the SUPERVISED gateway
TXT
