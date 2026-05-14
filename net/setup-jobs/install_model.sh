#!/usr/bin/env bash
set -euo pipefail

MODEL="${PRISM_MODEL:-llama3.2:1b}"
case "$MODEL" in
  llama3.2:1b|llama3.2:3b|llama3.1:8b) ;;
  *) echo "model is not allowlisted: $MODEL" >&2; exit 2 ;;
esac

OLLAMA_BIN="$(command -v ollama || true)"
if [[ -z "$OLLAMA_BIN" && -x /usr/local/bin/ollama ]]; then
  OLLAMA_BIN="/usr/local/bin/ollama"
fi
[[ -n "$OLLAMA_BIN" ]] || { echo "ollama binary not found" >&2; exit 1; }

if command -v systemctl >/dev/null 2>&1; then
  systemctl is-active --quiet ollama || systemctl restart ollama
fi

echo "pulling allowlisted model: $MODEL"
"$OLLAMA_BIN" pull "$MODEL"
"$OLLAMA_BIN" list | awk -v model="$MODEL" 'NR > 1 && $1 == model { found = 1 } END { exit found ? 0 : 1 }'
echo "model installed: $MODEL"
