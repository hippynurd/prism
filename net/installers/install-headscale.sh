#!/usr/bin/env bash
set -euo pipefail

# Native Headscale installer for PRISM Net.
# Downloads the upstream Linux binary, creates a dedicated service user, writes
# config and systemd unit files, starts the service, verifies the local health
# endpoint, and exits 0 only on success.

SERVICE_NAME="headscale"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_USER="headscale"
INSTALL_BIN="/usr/local/bin/headscale"
CONFIG_DIR="/etc/headscale"
DATA_DIR="/var/lib/headscale"
ARCHIVE="/tmp/headscale_linux_amd64"
DOWNLOAD_URL="https://github.com/juanfont/headscale/releases/latest/download/headscale_linux_amd64"

log() {
  printf '[headscale] %s\n' "$1"
}

fail() {
  printf '[headscale] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

install_packages() {
  log "installing required packages"
  apt-get update
  apt-get install -y curl sqlite3
}

ensure_user() {
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    log "user ${SERVICE_USER} already exists"
  else
    log "creating system user ${SERVICE_USER}"
    useradd --system --create-home --home-dir "${DATA_DIR}" --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi

  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${CONFIG_DIR}" "${DATA_DIR}"
}

install_binary() {
  if [[ -x "${INSTALL_BIN}" ]]; then
    log "Headscale binary already present"
    return
  fi

  log "downloading Headscale binary"
  curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE}"
  install -m 0755 "${ARCHIVE}" "${INSTALL_BIN}"
  [[ -x "${INSTALL_BIN}" ]] || fail "Headscale binary missing after install"
}

write_config() {
  log "writing Headscale config"
  cat > "${CONFIG_DIR}/config.yaml" <<'EOF'
server_url: http://127.0.0.1:8081
listen_addr: 127.0.0.1:8081
metrics_listen_addr: 127.0.0.1:9091
private_key_path: /var/lib/headscale/private.key
noise:
  private_key_path: /var/lib/headscale/noise_private.key
prefixes:
  v4: 100.64.0.0/10
  allocation: sequential
database:
  type: sqlite
  sqlite:
    path: /var/lib/headscale/db.sqlite
derp:
  server:
    enabled: false
disable_check_updates: true
EOF
  chown "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}/config.yaml"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=Headscale coordination server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=headscale
Group=headscale
ExecStart=/usr/local/bin/headscale serve
WorkingDirectory=/var/lib/headscale
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

  log "checking Headscale local health endpoint"
  curl -fsS http://127.0.0.1:9091/metrics >/dev/null || fail "Headscale metrics endpoint did not answer"
}

main() {
  require_root
  install_packages
  ensure_user
  install_binary
  write_config
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
