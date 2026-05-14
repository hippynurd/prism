#!/usr/bin/env bash
set -euo pipefail

# PRISM Net First Boot Script
# This script is the backend-side orchestrator for first boot.
# Iris remains the setup wizard, but this script brings up the local pieces
# she needs in order to guide the user through setup in the browser.

STATE_DIR="/var/lib/prism"
STATE_FILE="$STATE_DIR/firstboot.done"
SETUP_COMPLETE_FILE="$STATE_DIR/setup-complete"
PERSONALITY_FILE="/etc/prism/iris-personality"
LOG_FILE="/var/log/prism-firstboot.log"
ASSET_DIR="/usr/local/share/prism"
SETUP_MODE_FILE="/etc/prism/setup-mode"

OLLAMA_BIN="/usr/local/bin/ollama"
OLLAMA_SERVICE="ollama"
BACKEND_SERVICE="prism-setup-backend"
SETUP_SITE_LINK="/etc/nginx/sites-enabled/prism-setup"
IRIS_SITE_LINK="/etc/nginx/sites-enabled/prism-iris"

mkdir -p "$STATE_DIR" /etc/prism
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Exit cleanly if first boot already completed.
if [[ -f "$STATE_FILE" ]]; then
  exit 0
fi

echo "[prism] PRISM Net first boot starting at $(date -Is)"

# Setup mode is a real product state. Iris should meet the user first and stay
# in setup mode until service installation is finished.
printf 'setup\n' > "$SETUP_MODE_FILE"
rm -f "$SETUP_COMPLETE_FILE"

# Record a default personality early so every later component has a sane value,
# even before Iris helps the user pick the final tone in the browser.
printf 'Friendly\n' > "$PERSONALITY_FILE"

# Ollama is installed during image build. First boot should never depend on
# external DNS or bootstrap downloads before the setup UI is available.
if [[ ! -x "$OLLAMA_BIN" ]]; then
  echo "[prism] ERROR: expected baked Ollama binary missing at $OLLAMA_BIN"
  exit 1
fi

systemctl enable "$OLLAMA_SERVICE"
systemctl start "$OLLAMA_SERVICE"

# Bring up the browser-facing setup stack.
# Nginx serves the setup UI on port 80 and proxies both Ollama and the setup
# backend. The backend owns hardware detection and native service installs.
echo "[prism] Starting nginx for setup mode"
if [[ -f /etc/nginx/sites-available/prism-setup ]]; then
  rm -f /etc/nginx/sites-enabled/default "$IRIS_SITE_LINK"
  ln -sf /etc/nginx/sites-available/prism-setup "$SETUP_SITE_LINK"
fi
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "[prism] Starting setup backend"
if systemctl list-unit-files | grep -q "^${BACKEND_SERVICE}\.service"; then
  systemctl enable "$BACKEND_SERVICE"
  systemctl restart "$BACKEND_SERVICE"
else
  echo "[prism] Backend service unit missing; expecting image build to install it"
fi

# Iris now takes over in the browser. This script waits for a completion signal
# written by the setup backend when all chosen services and the final model are ready.
echo "[prism] Waiting for setup completion signal from backend"
until [[ -f "$SETUP_COMPLETE_FILE" ]]; do
  sleep 5
done

echo "[prism] Setup backend reported completion"

# Credential policy: first boot must not silently change passwords.
# The current documented temporary console bootstrap is root / prism, set by
# the image build. Mothership SSH key access remains available when the image
# is factory-provisioned.
echo "[prism] Leaving documented bootstrap credentials unchanged"

# Switch nginx from setup mode to Iris normal mode.
echo "[prism] Switching nginx from setup mode to Iris normal mode"
rm -f "$SETUP_SITE_LINK"
if [[ -f /etc/nginx/sites-available/prism-iris ]]; then
  ln -sf /etc/nginx/sites-available/prism-iris "$IRIS_SITE_LINK"
fi
nginx -t
systemctl reload nginx

# First boot is complete. Remove setup markers so future boots go directly to
# the normal PRISM experience.
touch "$STATE_FILE"
rm -f "$SETUP_MODE_FILE"
echo "[prism] First boot marked complete"

# Play the clip once. Audio failure should never block a usable system.
mpg123 -q "$ASSET_DIR/llama.mp3" 2>/dev/null || true

# Display the final banner and documented bootstrap policy on the local console.
{
  printf '\n'
  printf '\033[1;35m  ██████╗ \033[1;31m██████╗ \033[1;33m██╗\033[1;32m███████╗\033[1;36m███╗   ███╗\033[0m\n'
  printf '\033[1;35m  ██╔══██╗\033[1;31m██╔══██╗\033[1;33m██║\033[1;32m██╔════╝\033[1;36m████╗ ████║\033[0m\n'
  printf '\033[1;35m  ██████╔╝\033[1;31m██████╔╝\033[1;33m██║\033[1;32m███████╗\033[1;36m██╔████╔██║\033[0m\n'
  printf '\033[1;35m  ██╔═══╝ \033[1;31m██╔══██╗\033[1;33m██║\033[1;32m╚════██║\033[1;36m██║╚██╔╝██║\033[0m\n'
  printf '\033[1;35m  ██║     \033[1;31m██║  ██║\033[1;33m██║\033[1;32m███████║\033[1;36m██║ ╚═╝ ██║\033[0m\n'
  printf '\033[1;35m  ╚═╝     \033[1;31m╚═╝  ╚═╝\033[1;33m╚═╝\033[1;32m╚══════╝\033[1;36m╚═╝     ╚═╝\033[0m\n'
  printf '\n'
  printf '\033[1;32m  Your PRISM is ready.\033[0m\n'
  printf '\n'
  printf "  Iris personality : \033[1;36m$(cat "$PERSONALITY_FILE" 2>/dev/null || echo Friendly)\033[0m\n"
  printf '\n'
  printf "  Console login    : \033[1;33mroot / prism\033[0m\n"
  printf "  SSH access       : mothership factory key when provisioned\n"
  printf "  First boot does not randomize or silently change credentials.\n"
  printf '\n'
  printf "  Open browser to \033[1;32mhttp://prism.local\033[0m to meet Iris.\n"
  printf '\n'
} > /dev/tty1

echo "[prism] PRISM Net first boot finished at $(date -Is)"
