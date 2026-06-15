#!/bin/sh
# Full variant entrypoint: bind the first-party dashboard to Railway's $PORT,
# mirror secrets into the volume's .env, then hand off to the image's s6 PID-1.
set -e
export HERMES_HOME=/opt/data
export HOME=/opt/data
export HERMES_DASHBOARD_HOST="${HERMES_DASHBOARD_HOST:-0.0.0.0}"
export HERMES_DASHBOARD_PORT="${PORT:-9119}"

mkdir -p /opt/data
ENV_FILE=/opt/data/.env
touch "$ENV_FILE"; chmod 600 "$ENV_FILE" 2>/dev/null || true
for k in OPENAI_API_KEY OPENROUTER_API_KEY ANTHROPIC_API_KEY NOUS_API_KEY \
         TELEGRAM_BOT_TOKEN DISCORD_BOT_TOKEN SLACK_BOT_TOKEN EXA_API_KEY; do
  eval "v=\${$k:-}"
  [ -z "$v" ] && continue
  if grep -q "^$k=" "$ENV_FILE" 2>/dev/null; then
    sed -i "s|^$k=.*|$k=$v|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
done

# tmux session for: railway ssh -s hermes -- tmux attach -t hermes
tmux new-session -d -s hermes 2>/dev/null || true

# Hand off to the image's s6 PID-1 (/init) + main-wrapper. CMD ("gateway run")
# is auto-redirected to the supervised gateway service (auto-restart on crash);
# the dashboard runs as its own supervised s6 service because HERMES_DASHBOARD=1.
exec /init /opt/hermes/docker/main-wrapper.sh "$@"
