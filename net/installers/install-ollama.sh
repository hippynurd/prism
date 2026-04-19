#!/usr/bin/env bash
set -euo pipefail

# Native Ollama installer for PRISM Net.
# This script installs Ollama without Docker, ensures a systemd unit exists,
# starts the service, verifies it is reachable, and exits 0 only on success.

SERVICE_NAME="ollama"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
OLLAMA_BIN="/usr/local/bin/ollama"
OLLAMA_USER="ollama"
OLLAMA_HOME="/usr/share/ollama"

log() {
  printf '[ollama] %s\n' "$1"
}

fail() {
  printf '[ollama] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

ensure_user() {
  if id -u "${OLLAMA_USER}" >/dev/null 2>&1; then
    log "user ${OLLAMA_USER} already exists"
  else
    log "creating system user ${OLLAMA_USER}"
    useradd --system --create-home --home-dir "${OLLAMA_HOME}" --shell /usr/sbin/nologin "${OLLAMA_USER}"
  fi

  install -d -o "${OLLAMA_USER}" -g "${OLLAMA_USER}" "${OLLAMA_HOME}" "${OLLAMA_HOME}/.ollama"
}

install_binary() {
  if [[ -x "${OLLAMA_BIN}" ]]; then
    log "Ollama binary already present at ${OLLAMA_BIN}"
    return
  fi

  log "downloading and installing Ollama natively"
  curl -fsSL https://ollama.ai/install.sh | sh
  [[ -x "${OLLAMA_BIN}" ]] || fail "Ollama binary not found after install"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ollama
Group=ollama
Environment=HOME=/usr/share/ollama
Environment=OLLAMA_MODELS=/usr/share/ollama/.ollama/models
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
WorkingDirectory=/usr/share/ollama

[Install]
WantedBy=multi-user.target
EOF
}

enable_and_start() {
  log "reloading systemd"
  systemctl daemon-reload

  log "enabling ${SERVICE_NAME}"
  systemctl enable "${SERVICE_NAME}"

  log "starting ${SERVICE_NAME}"
  systemctl restart "${SERVICE_NAME}"
}

verify_service() {
  log "verifying ${SERVICE_NAME} is active"
  systemctl is-active --quiet "${SERVICE_NAME}" || fail "service is not active"

  log "checking local Ollama health endpoint"
  curl -fsS http://127.0.0.1:11434/api/tags >/dev/null || fail "Ollama API did not answer"
}

main() {
  require_root
  ensure_user
  install_binary
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
