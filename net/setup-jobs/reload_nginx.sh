#!/usr/bin/env bash
set -euo pipefail

command -v nginx >/dev/null 2>&1 || { echo "nginx not found" >&2; exit 1; }
nginx -t
if command -v systemctl >/dev/null 2>&1; then
  systemctl reload nginx
else
  nginx -s reload
fi
echo "nginx configuration validated and reloaded"
