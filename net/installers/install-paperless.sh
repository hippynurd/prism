#!/usr/bin/env bash
set -euo pipefail

# Native Paperless-ngx installer for PRISM Net.
# Installs required packages, creates a dedicated service account, builds a
# virtualenv, writes environment and service files, starts the service, verifies
# the local HTTP endpoint, and exits 0 only on success.

SERVICE_NAME="paperless"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_USER="paperless"
INSTALL_ROOT="/opt/paperless"
VENV_DIR="${INSTALL_ROOT}/venv"
CONFIG_DIR="/etc/paperless"
DATA_DIR="/var/lib/paperless"
MEDIA_DIR="${DATA_DIR}/media"
CONSUME_DIR="${DATA_DIR}/consume"
EXPORT_DIR="${DATA_DIR}/export"

log() {
  printf '[paperless] %s\n' "$1"
}

fail() {
  printf '[paperless] ERROR: %s\n' "$1" >&2
  exit 1
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fail "run as root"
}

install_packages() {
  log "installing required packages"
  apt-get update
  apt-get install -y python3 python3-venv python3-pip build-essential libpq-dev libxml2-dev libxslt1-dev libjpeg-dev zlib1g-dev ghostscript tesseract-ocr redis-server postgresql
}

ensure_user() {
  if id -u "${SERVICE_USER}" >/dev/null 2>&1; then
    log "user ${SERVICE_USER} already exists"
  else
    log "creating system user ${SERVICE_USER}"
    useradd --system --create-home --home-dir "${INSTALL_ROOT}" --shell /usr/sbin/nologin "${SERVICE_USER}"
  fi

  install -d -o "${SERVICE_USER}" -g "${SERVICE_USER}" "${INSTALL_ROOT}" "${CONFIG_DIR}" "${MEDIA_DIR}" "${CONSUME_DIR}" "${EXPORT_DIR}"
}

install_app() {
  if [[ -x "${VENV_DIR}/bin/gunicorn" ]]; then
    log "Paperless virtualenv already present"
    return
  fi

  log "creating virtualenv"
  python3 -m venv "${VENV_DIR}"

  log "installing Paperless-ngx into virtualenv"
  "${VENV_DIR}/bin/pip" install --upgrade pip wheel
  "${VENV_DIR}/bin/pip" install paperless-ngx gunicorn psycopg2-binary
  chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_ROOT}"
}

write_environment() {
  log "writing Paperless environment file"
  cat > "${CONFIG_DIR}/paperless.env" <<'EOF'
PAPERLESS_REDIS=redis://127.0.0.1:6379
PAPERLESS_DBHOST=127.0.0.1
PAPERLESS_DBNAME=paperless
PAPERLESS_DBUSER=paperless
PAPERLESS_DBPASS=paperless
PAPERLESS_URL=http://127.0.0.1:8000
PAPERLESS_MEDIA_ROOT=/var/lib/paperless/media
PAPERLESS_CONSUMPTION_DIR=/var/lib/paperless/consume
PAPERLESS_EXPORT_DIR=/var/lib/paperless/export
PAPERLESS_SECRET_KEY=prism-paperless-change-me
EOF
  chown "${SERVICE_USER}:${SERVICE_USER}" "${CONFIG_DIR}/paperless.env"
}

write_service() {
  log "writing systemd unit ${SERVICE_FILE}"
  cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=Paperless-ngx document server
After=network-online.target redis-server.service postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=paperless
Group=paperless
WorkingDirectory=/opt/paperless
EnvironmentFile=/etc/paperless/paperless.env
ExecStart=/opt/paperless/venv/bin/gunicorn paperless.asgi:application --bind 127.0.0.1:8000 --workers 3 -k uvicorn.workers.UvicornWorker
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
}

enable_and_start() {
  log "ensuring redis and postgresql are enabled"
  systemctl enable redis-server postgresql
  systemctl restart redis-server postgresql

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

  log "checking Paperless local endpoint"
  curl -fsS http://127.0.0.1:8000 >/dev/null || fail "Paperless did not answer on port 8000"
}

main() {
  require_root
  install_packages
  ensure_user
  install_app
  write_environment
  write_service
  enable_and_start
  verify_service
  log "installation complete"
}

main "$@" || exit 1
exit 0
