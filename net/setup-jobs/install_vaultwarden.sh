#!/usr/bin/env bash
set -euo pipefail

# Native Vaultwarden installer for PRISM Net.
# Downloads the upstream static release, creates a dedicated service account,
# writes a systemd unit, starts the service, verifies the HTTP endpoint, and
# exits 0 only on success.

SERVICE_NAME="vaultwarden"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_ROOT="/opt/vaultwarden"
DATA_DIR="/var/lib/vaultwarden"
ARCHIVE="/tmp/vaultwarden-x86_64.tar.gz"
DOWNLOAD_URL="https://github.com/dani-garcia/vaultwarden/releases/latest/download/vaultwarden-x86_64-unknown-linux-musl.tar.gz"
SERVICE_USER="vaultwarden"

log() {
  printf '[vaultwarden] %s\n' "$1"
}

fail() {
  printf '[vaultwarden] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

install_packages() {
  log "installing required packages"
  command -v apt-get >/dev/null 2>&1 || fail "apt-get not found; this job supports Debian-style PRISM images"
  apt-get update
  apt-get install -y curl tar
}

ensure_user() {
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    log "user ${SERVICE_USER} already exists"
  else
    log "creating system user ${SERVICE_USER}"
    useradd --system --create-home --home-dir "${INSTALL_ROOT}" --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi

  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${INSTALL_ROOT}" "${DATA_DIR}"
}

install_binary() {
  if [[ -x "${INSTALL_ROOT}/vaultwarden" ]]; then
    log "Vaultwarden binary already present"
    return
  fi

  log "downloading Vaultwarden release"
  curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE}"

  log "extracting Vaultwarden into ${INSTALL_ROOT}"
  tar -xzf "${ARCHIVE}" -C "${INSTALL_ROOT}"
  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}" "${DATA_DIR}"
  [[ -x "${INSTALL_ROOT}/vaultwarden" ]] || fail "Vaultwarden binary missing after extract"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=Vaultwarden password server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=vaultwarden
Group=vaultwarden
WorkingDirectory=/opt/vaultwarden
Environment=DATA_FOLDER=/var/lib/vaultwarden
Environment=ROCKET_ADDRESS=127.0.0.1
Environment=ROCKET_PORT=8080
ExecStart=/opt/vaultwarden/vaultwarden
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

enable_and_start() {
  command -v systemctl >/dev/null 2>&1 || fail "systemctl not found"

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

  log "checking Vaultwarden local web endpoint"
  curl -fsS http://127.0.0.1:8080 >/dev/null || fail "Vaultwarden did not answer on port 8080"
}

main() {
  require_root
  install_packages
  ensure_user
  install_binary
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
