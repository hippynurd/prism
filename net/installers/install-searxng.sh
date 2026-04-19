#!/usr/bin/env bash
set -euo pipefail

# Native SearXNG installer for PRISM Net.
# Installs Python and runtime dependencies, creates a virtualenv, installs
# SearXNG from PyPI, writes a minimal config and systemd unit, starts the
# service, verifies the HTTP endpoint, and exits 0 only on success.

SERVICE_NAME="searxng"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_USER="searxng"
INSTALL_ROOT="/opt/searxng"
VENV_DIR="${INSTALL_ROOT}/venv"
CONFIG_DIR="/etc/searxng"

log() {
  printf '[searxng] %s\n' "$1"
}

fail() {
  printf '[searxng] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

install_packages() {
  log "installing required packages"
  apt-get update
  apt-get install -y python3 python3-venv python3-pip git build-essential libxml2-dev libxslt1-dev zlib1g-dev libffi-dev
}

ensure_user() {
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    log "user ${SERVICE_USER} already exists"
  else
    log "creating system user ${SERVICE_USER}"
    useradd --system --create-home --home-dir "${INSTALL_ROOT}" --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi

  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${INSTALL_ROOT}" "${CONFIG_DIR}"
}

install_app() {
  if [[ -x "${VENV_DIR}/bin/searxng-run" ]]; then
    log "SearXNG virtualenv already present"
    return
  fi

  log "creating virtualenv"
  python3 -m venv "${VENV_DIR}"

  log "installing SearXNG into virtualenv"
  "${VENV_DIR}/bin/pip" install --upgrade pip wheel
  "${VENV_DIR}/bin/pip" install "searxng[uwsgi]"
  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}" "${CONFIG_DIR}"
}

write_config() {
  log "writing minimal SearXNG settings"
  cat > "${CONFIG_DIR}/settings.yml" <<'EOF'
use_default_settings: true
server:
  bind_address: 127.0.0.1
  port: 8888
  secret_key: prism-searxng-change-me
ui:
  static_use_hash: true
redis:
  url: false
EOF
  chown "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}/settings.yml"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=SearXNG metasearch
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=searxng
Group=searxng
WorkingDirectory=/opt/searxng
Environment=SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml
ExecStart=/opt/searxng/venv/bin/searxng-run
Restart=always
RestartSec=3

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

  log "checking SearXNG local endpoint"
  curl -fsS http://127.0.0.1:8888 >/dev/null || fail "SearXNG did not answer on port 8888"
}

main() {
  require_root
  install_packages
  ensure_user
  install_app
  write_config
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
