#!/usr/bin/env bash
# Slim variant entrypoint: bootstrap the volume, materialise secrets, keep the
# always-on response engine alive.
set -euo pipefail
export HERMES_HOME="${HERMES_HOME:-/data}"
export HOME="$HERMES_HOME"
mkdir -p "$HERMES_HOME"/{profiles,skills,memories,sessions,logs,backups}

# Mirror Railway-provided secrets into $HERMES_HOME/.env (idempotent). Hermes
# also reads the process env, but persisting keeps the volume self-contained.
ENV_FILE="$HERMES_HOME/.env"
touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
put_env() {
  local key="$1" val="${2:-}"
  [ -z "$val" ] && return 0
  if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >> "$ENV_FILE"
  fi
}
for k in OPENAI_API_KEY OPENROUTER_API_KEY ANTHROPIC_API_KEY NOUS_API_KEY \
         TELEGRAM_BOT_TOKEN DISCORD_BOT_TOKEN SLACK_BOT_TOKEN EXA_API_KEY; do
  eval "v=\${$k:-}"; put_env "$k" "${v:-}"
done

# Detached tmux session for: railway ssh -s hermes -- tmux attach -t hermes
# Independent of the gateway below — detaching never stops the responder.
tmux new-session -d -s hermes 2>/dev/null || true

# Keep-alive == the always-on response engine.
#   HERMES_KEEPALIVE=gateway  → always run the messaging gateway
#   HERMES_KEEPALIVE=idle     → just stay up for railway ssh (manual hermes chat)
#   HERMES_KEEPALIVE=auto     → gateway iff a platform token is present (default)
mode="${HERMES_KEEPALIVE:-auto}"
if [ "$mode" = "auto" ]; then
  if [ -n "${TELEGRAM_BOT_TOKEN:-}${DISCORD_BOT_TOKEN:-}${SLACK_BOT_TOKEN:-}" ]; then
    mode="gateway"
  else
    mode="idle"
  fi
fi
case "$mode" in
  gateway)
    echo "[hermes] starting gateway (response engine) — HERMES_HOME=$HERMES_HOME"
    exec hermes gateway run -v
    ;;
  *)
    echo "[hermes] no messaging platform set; idling for railway ssh. HERMES_HOME=$HERMES_HOME"
    exec tail -f /dev/null
    ;;
esac
