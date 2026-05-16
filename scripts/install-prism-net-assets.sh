#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?usage: install-prism-net-assets.sh ROOTFS}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NET_ROOT="$PROJECT_ROOT/net"

install -d \
  "$ROOTFS/usr/local/sbin" \
  "$ROOTFS/usr/local/bin" \
  "$ROOTFS/usr/local/lib/prism/setup-jobs" \
  "$ROOTFS/usr/local/share/prism" \
  "$ROOTFS/var/www/prism-setup" \
  "$ROOTFS/var/www/prism-chat" \
  "$ROOTFS/etc/systemd/system" \
  "$ROOTFS/etc/systemd/system/multi-user.target.wants" \
  "$ROOTFS/etc/nginx/sites-available" \
  "$ROOTFS/etc/prism"

install -m 0755 \
  "$NET_ROOT/first-boot/prism-firstboot.sh" \
  "$ROOTFS/usr/local/sbin/prism-firstboot"
install -m 0755 \
  "$NET_ROOT/ui/prism-setup-backend.py" \
  "$ROOTFS/usr/local/bin/prism-setup-backend"
install -m 0644 \
  "$NET_ROOT/nginx/prism-setup.conf" \
  "$ROOTFS/etc/nginx/sites-available/prism-setup"
install -m 0644 \
  "$NET_ROOT/nginx/prism-iris.conf" \
  "$ROOTFS/etc/nginx/sites-available/prism-iris"
install -m 0644 \
  "$NET_ROOT/ui/index.html" \
  "$ROOTFS/var/www/prism-setup/index.html"
install -m 0644 \
  "$NET_ROOT/ui/index.html" \
  "$ROOTFS/var/www/prism-chat/index.html"
install -m 0644 \
  "$NET_ROOT/iris/setup-prompt.txt" \
  "$ROOTFS/usr/local/share/prism/setup-prompt.txt"
install -m 0755 \
  "$NET_ROOT/setup-jobs/"*.sh \
  "$ROOTFS/usr/local/lib/prism/setup-jobs/"
install -m 0644 \
  "$NET_ROOT/motd/10-prism" \
  "$ROOTFS/etc/motd"
install -m 0644 \
  "$PROJECT_ROOT/assets/llama.mp3" \
  "$ROOTFS/usr/local/share/prism/llama.mp3"

cat > "$ROOTFS/etc/systemd/system/prism-firstboot.service" <<'EOF'
[Unit]
Description=PRISM Net first boot orchestration
After=network-online.target ollama.service
Wants=network-online.target
ConditionPathExists=!/var/lib/prism/firstboot.done

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/prism-firstboot
StandardInput=tty-force
StandardOutput=journal+console
StandardError=journal+console
TTYPath=/dev/tty1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > "$ROOTFS/etc/systemd/system/prism-setup-backend.service" <<'EOF'
[Unit]
Description=PRISM Net setup backend
After=network-online.target ollama.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/prism-setup-backend
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

ln -sf /etc/systemd/system/prism-firstboot.service \
  "$ROOTFS/etc/systemd/system/multi-user.target.wants/prism-firstboot.service"

cat > "$ROOTFS/etc/prism/README" <<'EOF'
PRISM Net configuration root

- /etc/prism/iris-personality stores the first-boot Iris persona choice.
- /etc/prism/setup-mode indicates first-boot setup state.
- /var/lib/prism/setup-complete is written by the setup backend when installs finish.
- /var/lib/prism/firstboot.done marks first-boot completion.
- /var/log/prism-firstboot.log records first-boot actions.
EOF
