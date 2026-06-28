#!/usr/bin/env bash
# Full/UI variant entrypoint (from-source build, no s6): bootstrap the volume,
# mirror secrets, then run the first-party dashboard + the gateway. If either
# process exits, the container exits so Railway (restartPolicy=ON_FAILURE)
# restarts it.
set -euo pipefail
export HERMES_HOME=/opt/data
export HOME=/opt/data
export HERMES_WEB_DIST="${HERMES_WEB_DIST:-/opt/hermes/hermes_cli/web_dist}"
# This image runs uniformly as root (no privilege-drop), so the gateway's
# "refusing to run as root" guard is safe to waive — there is no mixed-ownership
# risk when everything is root.
export HERMES_ALLOW_ROOT_GATEWAY="${HERMES_ALLOW_ROOT_GATEWAY:-1}"
mkdir -p /opt/data/{profiles,skills,memories,sessions,logs,backups}

# Mirror Railway-provided secrets into $HERMES_HOME/.env (idempotent).
ENV_FILE=/opt/data/.env
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
         TELEGRAM_BOT_TOKEN DISCORD_BOT_TOKEN SLACK_BOT_TOKEN \
         EXA_API_KEY FIRECRAWL_API_KEY FAL_KEY; do
  eval "v=\${$k:-}"; put_env "$k" "${v:-}"
done

PORT="${PORT:-8080}"
echo "[hermes-full] dashboard on 0.0.0.0:${PORT} + gateway — HERMES_HOME=${HERMES_HOME}"

# First-party dashboard (UI assets prebuilt → --skip-build). On a non-loopback
# bind the auth gate engages and REQUIRES an auth provider, or it refuses to
# start. Pick ONE (set as Railway variables):
#   • basic password (simplest):  HERMES_DASHBOARD_BASIC_AUTH_USERNAME,
#       HERMES_DASHBOARD_BASIC_AUTH_PASSWORD, HERMES_DASHBOARD_BASIC_AUTH_SECRET
#   • Nous Portal OAuth:          run `hermes dashboard register` (sets
#       HERMES_DASHBOARD_OAUTH_CLIENT_ID)
# Do NOT use --insecure on a public Railway domain (unauthenticated dashboard).
hermes dashboard --host 0.0.0.0 --port "${PORT}" --no-open --skip-build &
DASH=$!
# Always-on response engine.
hermes gateway run -v &
GW=$!

# If either supervised process exits, bring the container down so Railway restarts it.
wait -n
echo "[hermes-full] a supervised process exited; cycling container for restart"
kill "$DASH" "$GW" 2>/dev/null || true
exit 1
