# PRISM Offline v0.1

Date built: 2026-04-14
Status: complete, verified, compressed

## What These Files Are

This directory contains the PRISM Offline v0.1 disk image.

PRISM Offline is the heavier self-contained PRISM image:
- Debian 12 base system
- preinstalled Ollama
- `llama3.1:8b` already staged in the image
- nginx already configured
- Iris chat UI already present

This is the image to use when you want PRISM to boot with the major pieces already in place instead of downloading them on first boot.

## Files

- Raw image: `prism-v1-20260413.raw`
- Compressed image: `prism-v1-20260413.raw.gz`

## Sizes

- Raw size: 64G
- Compressed size: 8.4G

## SHA256

- `prism-v1-20260413.raw`
  `28f545c548c385b1408d0f9f5ca519b61b993cd1abac7e482d45b51a31cafe87`
- `prism-v1-20260413.raw.gz`
  `6a754ca77c2199626d371ee0e44e1e335a2be13f56c816404bb85dfc0fe7c3a3`

## What's Inside

- Debian 12 with GPT partitioning
- 512MB EFI system partition
- ext4 root partition
- GRUB UEFI bootloader
- Linux kernel and initramfs
- SSH enabled
- nginx enabled
- Ollama installed at `/usr/local/bin/ollama`
- `llama3.1:8b` model included
- Iris UI served from `/var/www/html/index.html`
- `/api/` proxied to local Ollama on `127.0.0.1:11434`

## How To Flash It

If you want the smaller file:

```bash
gunzip -k prism-v1-20260413.raw.gz
```

Write the raw image to a target disk:

```bash
sudo dd if=prism-v1-20260413.raw of=/dev/sdX bs=16M status=progress conv=fsync
sync
```

Replace `/dev/sdX` with the correct target disk.

## What To Do After Flashing

1. Boot the target machine from the written disk.
2. Wait for Debian to come up.
3. Find the system IP from DHCP or console.
4. Open the Iris UI in a browser.
5. Confirm `ollama` and `nginx` are running if you need to troubleshoot.

## Notes

- This is the Offline image, not the newer PRISM Net first-boot installer image.
- PRISM Net artifacts are stored on the build node under the configured render output path.
