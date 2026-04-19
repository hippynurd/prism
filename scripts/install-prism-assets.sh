#!/usr/bin/env bash
set -euo pipefail

ROOTFS="${1:?usage: install-prism-assets.sh ROOTFS}"
PROJECT_ROOT="/vault/pve-media/projects/prism"

install -d "$ROOTFS/usr/local/sbin" "$ROOTFS/etc/systemd/system" "$ROOTFS/etc/prism"
install -m 0755 "$PROJECT_ROOT/first-boot/prism-firstboot.sh" "$ROOTFS/usr/local/sbin/prism-firstboot"
install -m 0644 "$PROJECT_ROOT/first-boot/prism-firstboot.service" "$ROOTFS/etc/systemd/system/prism-firstboot.service"

cat > "$ROOTFS/etc/prism/README" <<'EOF'
PRISM configuration root

- /etc/prism/iris-personality stores the first-boot Iris persona choice.
- /var/lib/prism/firstboot.done marks first-boot completion.
- /var/log/prism-firstboot.log records first-boot actions.
EOF

cat > "$ROOTFS/etc/motd" <<'EOF'
PRISM v1 prototype image
Privacy-first Debian home server
This image is still being assembled by the Mothership factory.
EOF

mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/prism-firstboot.service \
  "$ROOTFS/etc/systemd/system/multi-user.target.wants/prism-firstboot.service"
