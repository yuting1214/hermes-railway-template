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

# Always-on response engine as PID 1 (Railway supervises it; restarts on crash).
# `hermes gateway run` stays up even with NO messaging platform configured — it
# keeps running cron + housekeeping — so a freshly-deployed agent is reachable
# over `railway ssh` for onboarding (`hermes auth add …`, `hermes chat`) with no
# keep-alive shim. Want a persistent shell? `railway ssh --session` (Railway
# provisions tmux on demand).
echo "[hermes] starting gateway (response engine) — HERMES_HOME=$HERMES_HOME"
exec hermes gateway run -v
