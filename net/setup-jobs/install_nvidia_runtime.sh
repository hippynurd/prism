#!/usr/bin/env bash
set -euo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "install_nvidia_runtime must run as root" >&2; exit 1; }

if ! command -v apt-get >/dev/null 2>&1; then
  echo "apt-get not found; NVIDIA runtime installer only supports Debian-style PRISM images" >&2
  exit 1
fi

if command -v lspci >/dev/null 2>&1; then
  if ! lspci | grep -Eiq 'NVIDIA|3D controller|VGA compatible controller|Display controller'; then
    echo "no display/GPU PCI device detected by lspci" >&2
    exit 1
  fi
else
  gpu_found=0
  for class_file in /sys/bus/pci/devices/*/class; do
    [[ -f "$class_file" ]] || continue
    if grep -Eq '0x0300|0x0301|0x0302' "$class_file"; then
      gpu_found=1
      break
    fi
  done
  if [[ "$gpu_found" -ne 1 ]]; then
    echo "no display/GPU PCI device detected by sysfs" >&2
    exit 1
  fi
fi

export DEBIAN_FRONTEND=noninteractive
echo "updating apt metadata"
apt-get update
echo "installing NVIDIA runtime packages"
apt-get install -y nvidia-driver firmware-misc-nonfree pciutils

if command -v update-initramfs >/dev/null 2>&1; then
  update-initramfs -u
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || {
    echo "nvidia-smi exists but the driver is not usable yet; reboot may be required" >&2
    exit 1
  }
else
  echo "nvidia-smi was not installed" >&2
  exit 1
fi

echo "NVIDIA runtime installed and nvidia-smi responded"
