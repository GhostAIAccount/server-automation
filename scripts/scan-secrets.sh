#!/usr/bin/env bash
# Fails (exit 1) if tracked/staged-looking files contain likely secrets.
# Usage: scripts/scan-secrets.sh [dir=.]
set -u
DIR="${1:-.}"
PATTERNS=(
  'eyJ[A-Za-z0-9_-]{20,}'                         # JWT / Cloudflare tunnel tokens (base64 JSON)
  'AKIA[0-9A-Z]{16}'                              # AWS key id
  'gh[pousr]_[A-Za-z0-9]{30,}'                    # GitHub tokens
  'sk-[A-Za-z0-9_-]{20,}'                         # API keys
  'xox[baprs]-[A-Za-z0-9-]{10,}'                  # Slack
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '(?i)(password|passwd|secret|token|api[_-]?key|apikey|authorization|bearer)["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+_.-]{8,}'
  '(?i)"(AccountTag|TunnelSecret)"'               # cloudflared credentials file
  '(?i)tunnel_secret'
  '[0-9a-f]{32,}'                                  # long hex (api keys)
)
fail=0
for p in "${PATTERNS[@]}"; do
  out=$(grep -rIPn --exclude-dir=.git --exclude=scan-secrets.sh --exclude=.env.example \
        --exclude=export-from-server.sh -e "$p" "$DIR" 2>/dev/null \
        | grep -v 'REDACTED' | grep -v '<[A-Z_]*>' | grep -vE '=\s*$' | grep -vE '\$\{?[A-Z_]+\}?') 
  if [ -n "$out" ]; then echo "!! Possible secret (pattern: $p)"; echo "$out" | head -20; fail=1; fi
done
# forbidden files
bad=$(find "$DIR" -path "$DIR/.git" -prune -o \( -name '.env' -o -name '*.pem' -o -name '*.key' -o -name 'cert.pem' -o -name 'credentials*.json' \) -print)
[ -n "$bad" ] && { echo "!! Forbidden files present:"; echo "$bad"; fail=1; }
[ $fail -eq 0 ] && echo "OK: no likely secrets found." || echo "FAILED: fix the above before committing."
exit $fail
