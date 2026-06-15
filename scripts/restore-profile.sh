#!/usr/bin/env bash
#
# restore-profile.sh — import a profile tarball onto a (fresh) Railway Hermes
# service, to recover/clone your agent on a new device or after a teardown.
#
# Because `railway ssh` can't reliably stream files INTO a container (stdin
# hangs; complex `sh -c` is mangled), we fetch the archive BY URL from inside the
# container (curl is present in both variants). Host the tarball somewhere the
# container can reach — e.g. an R2 pre-signed URL, or a raw private-repo URL with
# an embedded token. (If you used `backup-pull.sh SINK=r2`, generate a pre-signed
# GET URL for that object.)
#
# Run from a directory linked to the Railway project.
#
# Usage:
#   SERVICE=hermes [NAME=default] ARCHIVE_URL="https://…/default-XXXX.tar.gz" ./restore-profile.sh
#
set -euo pipefail
SERVICE="${SERVICE:-hermes}"
NAME="${NAME:-}"
URL="${ARCHIVE_URL:?set ARCHIVE_URL to a URL the container can fetch}"
REMOTE="/tmp/restore-$(date -u +%s).tar.gz"

echo "Fetching archive into container ($SERVICE) ..."
railway ssh -s "$SERVICE" -- curl -fsSL "$URL" -o "$REMOTE"

echo "Importing ..."
if [ -n "$NAME" ]; then
  railway ssh -s "$SERVICE" -- hermes profile import "$REMOTE" --name "$NAME"
else
  railway ssh -s "$SERVICE" -- hermes profile import "$REMOTE"
fi
railway ssh -s "$SERVICE" -- rm -f "$REMOTE" >/dev/null 2>&1 || true

cat <<'TXT'

Imported. Secrets are NOT in the export, so on this fresh service:
  • re-set messaging/provider keys:  railway variables --set 'TELEGRAM_BOT_TOKEN=...' -s hermes
  • re-establish Codex auth:          ./onboard-codex.sh
TXT
