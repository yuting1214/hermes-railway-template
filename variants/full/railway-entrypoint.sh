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

# Dashboard session-signing secret: auto-generated on first boot and persisted to
# the volume, so it is never a field the deployer has to fill from empty. (You
# provide USERNAME + PASSWORD as Railway variables.) Set it yourself to override.
if [ -z "${HERMES_DASHBOARD_BASIC_AUTH_SECRET:-}" ]; then
  s="$(grep '^HERMES_DASHBOARD_BASIC_AUTH_SECRET=' "$ENV_FILE" 2>/dev/null | head -1 | cut -d= -f2-)"
  [ -z "$s" ] && { s="$(python -c 'import secrets;print(secrets.token_urlsafe(48))')"; \
    echo "[hermes-full] generated a dashboard session secret (persisted to the volume)"; }
  export HERMES_DASHBOARD_BASIC_AUTH_SECRET="$s"; put_env HERMES_DASHBOARD_BASIC_AUTH_SECRET "$s"
fi

# First-party dashboard (UI assets prebuilt → --skip-build). On a public bind the
# auth gate REQUIRES basic-auth: you set HERMES_DASHBOARD_BASIC_AUTH_USERNAME +
# _PASSWORD (Railway variables); _SECRET is handled above. (Alternative: Nous
# Portal OAuth via `hermes dashboard register`.) Never use --insecure on a public domain.
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
