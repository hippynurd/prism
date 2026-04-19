#!/usr/bin/env bash
set -euo pipefail

# Native AdGuard Home installer for PRISM Net.
# Installs the upstream Linux release, writes a systemd unit, starts the
# service, verifies the web API port answers, and exits 0 only on success.

SERVICE_NAME="adguardhome"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
INSTALL_ROOT="/opt/AdGuardHome"
ARCHIVE="/tmp/adguardhome_linux_amd64.tar.gz"
DOWNLOAD_URL="https://static.adguard.com/adguardhome/release/AdGuardHome_linux_amd64.tar.gz"

log() {
  printf '[adguard] %s\n' "$1"
}

fail() {
  printf '[adguard] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

install_packages() {
  log "installing required packages"
  apt-get update
  apt-get install -y curl tar
}

install_binary() {
  if [[ -x "${INSTALL_ROOT}/AdGuardHome" ]]; then
    log "AdGuard Home binary already present"
    return
  fi

  log "downloading AdGuard Home release"
  curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE}"

  log "extracting release into /opt"
  tar -xzf "${ARCHIVE}" -C /opt
  [[ -x "${INSTALL_ROOT}/AdGuardHome" ]] || fail "AdGuard Home binary missing after extract"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=AdGuard Home
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/AdGuardHome
ExecStart=/opt/AdGuardHome/AdGuardHome --no-check-update -w /opt/AdGuardHome
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

  log "checking AdGuard Home local web endpoint"
  curl -fsS http://127.0.0.1:3000 >/dev/null || fail "AdGuard Home did not answer on port 3000"
}

main() {
  require_root
  install_packages
  install_binary
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
