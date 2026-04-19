#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUITE="${SUITE:-bookworm}"
ARCH="${ARCH:-amd64}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
WORKDIR="${WORKDIR:-/tmp/prism-build}"
ROOTFS_DIR="${ROOTFS_DIR:-$WORKDIR/rootfs}"
IMAGE_RAW="${IMAGE_RAW:-$WORKDIR/prism-v1.raw}"
IMAGE_GZ="${IMAGE_GZ:-$WORKDIR/prism-v1.img.gz}"
IMAGE_SIZE_GB="${IMAGE_SIZE_GB:-64}"
HOSTNAME="${HOSTNAME:-prism}"
TIMEZONE="${TIMEZONE:-America/Los_Angeles}"
PACKAGE_FILE="${PACKAGE_FILE:-$REPO_ROOT/configs/packages.base}"
ASSET_INSTALLER="${ASSET_INSTALLER:-$REPO_ROOT/scripts/install-prism-assets.sh}"

LOOPDEV=""
cleanup() {
  set +e
  if mountpoint -q "$ROOTFS_DIR/boot/efi"; then umount "$ROOTFS_DIR/boot/efi"; fi
  if mountpoint -q "$ROOTFS_DIR/dev/pts"; then umount "$ROOTFS_DIR/dev/pts"; fi
  if mountpoint -q "$ROOTFS_DIR/dev"; then umount "$ROOTFS_DIR/dev"; fi
  if mountpoint -q "$ROOTFS_DIR/proc"; then umount "$ROOTFS_DIR/proc"; fi
  if mountpoint -q "$ROOTFS_DIR/sys"; then umount "$ROOTFS_DIR/sys"; fi
  if mountpoint -q "$ROOTFS_DIR"; then umount "$ROOTFS_DIR"; fi
  if [[ -n "$LOOPDEV" ]]; then losetup -d "$LOOPDEV"; fi
}
trap cleanup EXIT

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

for cmd in debootstrap sgdisk losetup mkfs.vfat mkfs.ext4 blkid mount chroot grub-install update-initramfs pigz; do
  require "$cmd"
done
require "$ASSET_INSTALLER"

mkdir -p "$WORKDIR"
rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

truncate -s "${IMAGE_SIZE_GB}G" "$IMAGE_RAW"
sgdisk --zap-all "$IMAGE_RAW"
sgdisk -og "$IMAGE_RAW"
sgdisk -n 1:1MiB:+512MiB -t 1:ef00 -c 1:"EFI System" "$IMAGE_RAW"
sgdisk -n 2:0:0 -t 2:8304 -c 2:"PRISM Root" "$IMAGE_RAW"

LOOPDEV="$(losetup --find --show --partscan "$IMAGE_RAW")"
udevadm settle

mkfs.vfat -F 32 -n PRISM_EFI "${LOOPDEV}p1"
mkfs.ext4 -F -L PRISM_ROOT "${LOOPDEV}p2"

mount "${LOOPDEV}p2" "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR/boot/efi"
mount "${LOOPDEV}p1" "$ROOTFS_DIR/boot/efi"

PACKAGES="$(paste -sd, "$PACKAGE_FILE")"
debootstrap \
  --arch="$ARCH" \
  --variant=minbase \
  --include="$PACKAGES" \
  "$SUITE" "$ROOTFS_DIR" "$MIRROR"

"$ASSET_INSTALLER" "$ROOTFS_DIR"

echo "$HOSTNAME" > "$ROOTFS_DIR/etc/hostname"
cat > "$ROOTFS_DIR/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $HOSTNAME

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

ROOT_UUID="$(blkid -s UUID -o value "${LOOPDEV}p2")"
EFI_UUID="$(blkid -s UUID -o value "${LOOPDEV}p1")"
cat > "$ROOTFS_DIR/etc/fstab" <<EOF
UUID=$ROOT_UUID / ext4 defaults 0 1
UUID=$EFI_UUID /boot/efi vfat umask=0077 0 1
EOF

cat > "$ROOTFS_DIR/etc/default/locale" <<EOF
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

cat > "$ROOTFS_DIR/etc/timezone" <<EOF
$TIMEZONE
EOF

mount --bind /dev "$ROOTFS_DIR/dev"
mount --bind /dev/pts "$ROOTFS_DIR/dev/pts"
mount --bind /proc "$ROOTFS_DIR/proc"
mount --bind /sys "$ROOTFS_DIR/sys"

chroot "$ROOTFS_DIR" /bin/bash -eux <<'EOF'
echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
locale-gen
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
systemctl enable NetworkManager systemd-resolved ssh nginx mariadb postgresql redis-server fail2ban
grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --removable
update-initramfs -u
EOF

cat > "$ROOTFS_DIR/etc/motd" <<'EOF'
PRISM build image
This is an in-progress image assembled by the Mothership factory pipeline.
EOF

echo "Base image assembled at $IMAGE_RAW"
echo "Compress with: pigz -c $IMAGE_RAW > $IMAGE_GZ"
