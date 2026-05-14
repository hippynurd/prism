#!/usr/bin/env bash
set -euo pipefail

SETUP_COMPLETE_FILE="${PRISM_SETUP_COMPLETE_FILE:-/var/lib/prism/setup-complete}"
mkdir -p "$(dirname "$SETUP_COMPLETE_FILE")"
printf 'complete\n' > "$SETUP_COMPLETE_FILE"
echo "setup completion marker written: $SETUP_COMPLETE_FILE"
