#!/usr/bin/env bash
# Run ON YOUR SERVER. Copies your setup into this repo's layout, redacts
# secrets, scans the result, and only then lets you commit.
#
#   1. Edit scripts/export.conf (copy from export.conf.example) with your paths.
#   2. ./scripts/export-from-server.sh
#   3. Review `git diff`, then commit & push.
#
# Never copied: .env, *.pem, *.key, cloudflared credentials JSON, cert.pem,
# Jellyfin data/config DBs, logs, media.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONF="${1:-$REPO/scripts/export.conf}"
[ -f "$CONF" ] || { echo "Missing $CONF (copy scripts/export.conf.example)"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"

copy() { # copy <src> <dest-subdir>
  local src="$1" dest="$REPO/$2"
  [ -e "$src" ] || { echo "skip (missing): $src"; return; }
  mkdir -p "$dest"
  rsync -a --prune-empty-dirs \
    --exclude='.env' --exclude='*.pem' --exclude='*.key' --exclude='*.crt' \
    --exclude='cert.pem' --exclude='credentials*.json' --exclude='*.log' \
    --exclude='*.db' --exclude='*.sqlite*' --exclude='node_modules' \
    --exclude='__pycache__' --exclude='.git' --exclude='data' --exclude='cache' \
    --exclude='[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*-[0-9a-f]*.json' \
    "$src" "$dest/"
  echo "copied: $src -> $2"
}

for p in "${JELLYFIN_FILES[@]:-}";   do [ -n "$p" ] && copy "$p" server/jellyfin;   done
for p in "${CLOUDFLARE_FILES[@]:-}"; do [ -n "$p" ] && copy "$p" server/cloudflare; done
for p in "${DASHBOARD_FILES[@]:-}";  do [ -n "$p" ] && copy "$p" server/dashboard;  done
for p in "${STARTUP_FILES[@]:-}";    do [ -n "$p" ] && copy "$p" server/startup;    done

# Redact common inline secrets in text files
find "$REPO/server" -type f -print0 | while IFS= read -r -d '' f; do
  file -b --mime "$f" | grep -q '^text' || continue
  sed -E -i \
    -e 's/(eyJ[A-Za-z0-9_-]{20,})/REDACTED_TOKEN/g' \
    -e 's/((TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY|APIKEY)[A-Za-z0-9_]*[[:space:]]*[=:][[:space:]]*)["'"'"']?[^"'"'"'[:space:]#]+["'"'"']?/\1REDACTED/Ig' \
    -e 's/(--token[ =])[^ ]+/\1REDACTED/g' \
    -e 's/([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/<UUID>/g' \
    -e 's/([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}/<HOST>:PORT/g' \
    "$f"
done
echo "Redaction done. Scanning..."
"$REPO/scripts/scan-secrets.sh" "$REPO" || { echo "Resolve findings manually, then re-run the scanner."; exit 1; }
echo "Safe to review: git -C $REPO status && git -C $REPO diff"
