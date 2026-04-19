## 2026-04-13T11:29:03-07:00 Phase 1 start
- validating cluster, FM09 Ollama, shared storage, and factory mode

## 2026-04-13T12:35:35-07:00 Phase 1 complete
- wrote factory-status.md
- FM09 70B endpoint verified at http://192.168.14.109:11435
- moving into PRISM build work
## 2026-04-13T12:37:00-07:00 Phase 2 start
- created PRISM workspace in vault
- confirmed build output path is available
- confirmed local image build toolchain is present (debootstrap/mmdebstrap/grub/xorriso/sgdisk/qemu-img)

## 2026-04-13T12:50:00-07:00 First-boot scaffolding
- staged a PRISM first-boot systemd unit and script in the project workspace
- first boot currently asks only for Iris personality, generates a random root password, sets it, and displays it once on tty1
- wired the image build script to install staged PRISM assets into the rootfs after debootstrap completes

## 2026-04-13T16:45:00-07:00 Base image recovery
- repaired a partial debootstrap image in place instead of rebuilding
- root cause was incomplete package configuration around `polkitd` and `network-manager`
- installed the missing `libpam-systemd` dependency in the chroot, then completed `dpkg --configure -a`
- installed staged PRISM assets into the image and enabled `prism-firstboot.service`
- generated initramfs and completed EFI bootloader install at `/boot/efi/EFI/BOOT/BOOTX64.EFI`
- FM09 was consulted for higher-level build-plan guidance, but the local package repair was resolved directly without waiting on model output

## 2026-04-14 PRISM Offline v0.1 COMPLETE
- Added symlink /usr/bin/ollama -> /usr/local/bin/ollama
- Verification passed all checks
- Compressed: gzip -k -9 produced 8.4GB .raw.gz
- SHA256 raw: 28f545c548c385b1408d0f9f5ca519b61b993cd1abac7e482d45b51a31cafe87
- SHA256 gz:  6a754ca77c2199626d371ee0e44e1e335a2be13f56c816404bb85dfc0fe7c3a3
- Offline v0.1 build closed. Standing by for Net v0.1 planning.

## 2026-04-14 Session Handoff
- PRISM Offline v0.1 is complete, compressed, and checksummed.
- PRISM Net v0.1 has been fully designed and specced at the planning level.
- Files created today for Net build:
  - `configs/packages.net`
  - `net/motd/10-prism`
  - `net/first-boot/prism-firstboot.sh`
- `llama.mp3` was saved to `assets/llama.mp3`
- Colored MOTD banner was saved to `net/motd/10-prism`
- Net first-boot script first draft is in progress at `net/first-boot/prism-firstboot.sh`
- Next session should focus on:
  - Finalizing firstboot script native installs
  - Building the Net image
  - Getting it booting on the 7020 prototype
- Signed off: 2026-04-14

## 2026-04-14T20:07:27-07:00 PRISM Net architecture pass
- confirmed PRISM Offline v0.1 remains complete, verified, compressed, and checksummed
- decided PRISM Net will keep Iris as the setup wizard on all supported hardware, including 8GB machines, by starting setup on `llama3.2:1b`
- rewrote the Net firstboot script as an orchestrator only, with browser-first setup flow and backend completion handoff instead of a monolithic installer script
- created `net/iris/setup-prompt.txt` to define setup-mode Iris behavior, hardware explanation flow, service guidance, and completion messaging
- created `net/ui/prism-setup-backend.py` with hardware JSON, install start endpoint, SSE progress stream, and completion signal endpoint
- created `net/nginx/prism-setup.conf` and `net/nginx/prism-iris.conf` to separate first-boot setup mode from normal assistant mode
- created `net/README.md` to document the Net image purpose, first-boot flow, design decisions, and honest current status
- appended `## PRISM Net v0.1 Architecture Decisions` to the main product notes so the rationale lives in the primary design record
- current state: architecture is concrete enough to build against, but native install paths still need finishing before a real Net image build
- next steps:
  - finalize firstboot script native installs and service-unit expectations
  - build the Net image
  - get it booting on the 7020 prototype

## 2026-04-14T22:40:00-07:00 Session handoff
- reviewed all six native installer scripts under `net/installers/`
- confirmed each installer stays on a native path, writes a systemd unit, verifies startup, and includes explanatory comments
- no installer checklist fixes were needed for:
  - `install-ollama.sh`
  - `install-adguard.sh`
  - `install-vaultwarden.sh`
  - `install-searxng.sh`
  - `install-paperless.sh`
  - `install-headscale.sh`
- wrote `README.md` at the PRISM repo root for GitHub publication
- wrote `mothership-README.md` to document the control node, factory story, FunkMob, EXO findings, `llama.cpp` path, FM09 70B proof, and PRISM connection
- wrote `funkmob-README.md` to document the hardware story, node roles, distributed inference experiments, what worked, what failed, and why it matters to PRISM
- earlier in this session:
  - fixed the shared Iris chat UI to use `currentModel`
  - added `setModel(modelName)` to support switching from setup model to final model
  - copied the fixed chat UI to `/var/www/html/index.html`
  - wrote the shared PRISM GitHub README
  - wrote native installer scripts
  - updated `progress.md` to mark PRISM Net ready to build
- current file state:
  - PRISM Offline v0.1 remains complete and checksummed
  - PRISM Net architecture, UI, prompt, README, installer scripts, and progress tracking are all in place
  - no Net image has been built yet
  - no new scripts were executed
  - no images were mounted
  - no build work was started
- what is left:
  - build the PRISM Net image
  - wire the firstboot/backend/installers into a real image path
  - verify first-boot end-to-end behavior
  - boot test on the 7020 prototype
- start next session with:
  - main project context file
- signed off: 2026-04-14

## 2026-04-15 BOOT TEST PASSED
- VM 201 created on Proxmox MotherShip
- PRISM Offline v0.1 booted clean
- Ollama running, llama3.1:8b confirmed present
- nginx running, Iris UI serving HTTP 200
- Network accessible at 192.168.14.201
- Boot test: PASSED
- PRISM Offline v0.1 is complete and verified.

## 2026-04-16 Iris First Response Benchmark

VM specs:
- Host: FunkMob (Dell OptiPlex 7020, recycled)
- VM RAM: 8GB
- CPU: shared VM CPU, no GPU

Model: llama3.1:8b
Prompt: "Hello Iris, are you there?"
Response: "Hello! How are you today? Is there 
           something I can help you with or 
           would you like to chat?"

Metrics:
- total_duration:      163,305,358,496 ns (163 seconds)
- load_duration:           195,660,615 ns
- prompt_eval_count:    12 tokens
- prompt_eval_duration: 47,267,056,301 ns
- eval_count:           23 tokens
- eval_duration:       115,789,785,378 ns
- tokens per second:   ~0.14 t/s

Notes:
- Direct Ollama works
- nginx 300s timeout insufficient for this hardware
- FM09 migration planned for comparison benchmark

## 2026-04-16 nginx proxy test PASSED
- curl http://192.168.14.201/api/chat returned HTTP 200
- Response time: 157.282 seconds through nginx proxy
- Iris responded successfully through nginx
- Previous 504 errors were likely model still loading
- nginx proxy to Ollama: CONFIRMED WORKING

## 2026-04-18 PRISM Net image build complete
- Reference builder: FM09
- Raw image: builder output raw image artifact
- Compressed image: builder output compressed image artifact
- Raw size: 32G
- Compressed size: 1015M
- SHA256 raw: `0723be090ae379fbfe09e5d6857a7e17dea59ce0582af10545f0c192fafc54d1`
- SHA256 raw.gz: `ddb6f354a1ea2592e655cdc82c72306805ff7053231cdc761fd0f7ad9a63bc1f`
- Verification: PASS after fixing MOTD installation to `/etc/update-motd.d/10-prism`

## 2026-04-18 Evening Session Complete
Timestamp: 2026-04-18T22:31:44-07:00

Completed:
- PRISM Net v0.1 built, verified, compressed (1GB)
- llm-on-recycling.md written and ready for GitHub
- 405B cluster experiment documented
- Gaming computer running Ollama with GTX 1050 Ti GPU
- Aider installed on gaming computer
- gh CLI installed on mothership
- GitHub push prepared for tomorrow

Next session:
- gh auth login on mothership
- Create and push GitHub repos
- Boot test PRISM on real 7020 hardware
- Start with: read the main project context file
