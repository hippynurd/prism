## PRISM Build Spec

Date: 2026-04-13
Status: Draft

### Target

- Product: PRISM v1
- Base OS: Debian 12
- Hardware target: Dell OptiPlex 7020
- Deployment target: PXE-deliverable image for iVentoy
- Output artifact: `/vault/pve-media/images/prism-v1-20260413.img.gz`

### Core Platform Rules

- No Proxmox
- Bare-metal Debian host
- Prefer direct systemd services
- No hardcoded passwords
- No telemetry
- Full root access retained

### First Boot Requirements

- Ask one question only:
  - Iris personality
  - `Professional`
  - `Friendly`
  - `Playful`
  - `Zen`
  - `Technical`
- Generate a fresh random password on first boot
- Display that password once
- Store runtime state so the first-boot flow does not repeat
- Play the one-time Iris first-boot soundbite after Iris is ready

### Core Services

- Vaultwarden
- AdGuard
- Nextcloud
- SearXNG
- Paperless
- Nginx
- Fail2ban
- Headscale
- Authelia

### Build Direction

Current working assumption:
- Build a bootable disk image directly rather than depending on an interactive installer
- Assemble a Debian rootfs with debootstrap or mmdebstrap
- Apply PRISM configuration in chroot
- Install bootloader for UEFI boot
- Compress the resulting disk image for iVentoy delivery

This assumption is provisional until FM09 returns the architecture recommendation.

### Immediate Build Tasks

- Choose final image assembly method
- Define partition layout for the 7020 target
- Define service packaging and configuration paths
- Define first-boot orchestration
- Define Iris local runtime shape
- Define reverse proxy and authentication topology
- Define Nextcloud and Paperless storage layout
