# PRISM Net

## The Pitch
Boot it. Meet Iris. Let PRISM build itself in front of you.

PRISM Net is the network-first PRISM image. It starts small, downloads what it needs on first boot, and lets Iris guide the owner through setup in the browser instead of burying them in an installer.

It is the lighter, more flexible counterpart to PRISM Offline.

## What PRISM Net Is
PRISM Net is a minimal PRISM image designed to get onto hardware fast and then assemble the full system on first boot using live downloads and native installs.

The first thing the owner meets is Iris.

Not a shell script pretending to be a wizard.
Not a hidden black-box appliance flow.
Iris.

That matters because PRISM is supposed to feel local, human, inspectable, and honest from the first minute.

## How It Differs From PRISM Offline
PRISM Offline ships with the heavier pieces already baked into the image:
- Ollama installed
- model already present
- nginx and the Iris chat UI already in place
- larger final image

PRISM Net takes the opposite approach:
- smaller base image
- downloads services on first boot
- starts with a lightweight setup model
- lets the user choose what gets installed
- switches to the final Iris model after setup

Offline is the ready-to-go artifact.
Net is the lighter, more adaptable installer experience.

## The Problem It Solves
Not every PRISM build should be a giant preloaded image.

Sometimes the right answer is:
- get the image onto the machine quickly
- boot with minimal assumptions
- detect the actual hardware
- install only what makes sense
- let the owner see what is happening

PRISM Net solves that without throwing away the product identity.

The owner still meets Iris first.
The system still stays local-first and root-accessible.
The setup still explains itself instead of hiding behind a branded fog.

## First Boot Flow
Here is the plain-English first boot path:

1. PRISM Net boots into a minimal Debian-based PRISM environment.
2. The firstboot script installs Ollama natively if it is not already present.
3. It pulls `llama3.2:1b` immediately because that model is light, fast, and works comfortably even on 8GB machines.
4. Nginx starts in setup mode and serves the setup UI.
5. The setup backend starts on port `5000`.
6. The owner opens `http://prism.local`.
7. Iris introduces herself, explains PRISM in one sentence, and summarizes detected hardware.
8. Iris offers either:
   - Just set it up
   - Let me choose
9. The backend installs the selected services natively and reports progress back to the browser.
10. If the machine has enough RAM, the backend pulls the final Iris model for normal use:
    - 8GB class: `llama3.2:1b`
    - 16GB class: `llama3.2:3b`
    - 32GB class: `llama3.1:8b`
11. Setup completes, the llama clip plays once, the one-time root password is shown on `tty1`, and nginx switches from setup mode to normal Iris mode.

## What Each File Does
### `first-boot/prism-firstboot.sh`
The firstboot orchestrator.

It does not try to be the wizard itself.
It brings up the local pieces Iris needs:
- native Ollama install
- setup model pull
- nginx in setup mode
- setup backend startup
- wait for backend completion
- final tty1 completion banner and one-time password display

### `iris/setup-prompt.txt`
The setup-mode Iris system prompt.

This defines:
- Iris tone during setup
- how she explains detected hardware
- how she offers choices
- how she reports installation progress
- how she closes out setup cleanly

### `ui/prism-setup-backend.py`
The local setup backend on port `5000`.

It exposes:
- `GET /hardware`
- `POST /install`
- `GET /progress`
- `POST /complete`

It owns hardware detection, native install steps, progress events, and the completion signal the firstboot script watches for.

### `nginx/prism-setup.conf`
Nginx config for first boot.

It serves:
- setup UI
- Ollama API proxy at `/api/`
- setup backend proxy at `/setup/`

### `nginx/prism-iris.conf`
Nginx config for normal operation after setup.

It serves:
- normal Iris chat UI
- Ollama API proxy

### `motd/10-prism`
Colored PRISM identity banner for login sessions.

### `configs/packages.net`
Package list for the smaller Net image path.

Right now it is only beginning to take shape.

## Design Decisions And Why
### Iris Is The Wizard
This is the most important decision in PRISM Net.

Even on smaller machines, Iris is still the first-boot guide because PRISM should not abandon its identity the moment hardware gets tighter.

An 8GB machine still has enough headroom to run a 1B setup model and the OS during setup.
That means there is no need to fall back to a sterile scripted wizard just because the hardware is modest.

### Start With 1B, Switch Later
Setup starts on `llama3.2:1b` for one reason:
speed with headroom.

That model gets Iris online quickly, keeps RAM pressure low, and lets setup proceed without pretending every machine should start on 8B.

After setup, PRISM can move to the right long-term model for the actual hardware.

### Native Installs Over Docker
PRISM Net is being designed around native installs and systemd services where practical.

Why:
- more transparent
- easier to inspect
- less hidden orchestration
- fits the "no black boxes" philosophy better

That does not mean packaging is always simple.
It means the default posture is inspectable Linux services first.

### Web UI Over Whiptail
PRISM still exposes terminal access, but setup should happen in the browser because:
- it is more approachable
- it gives Iris room to explain what is happening
- it is easier to show progress honestly
- it feels like a product instead of a maintenance shell

### Hardware-Gated Optional Services
Not every machine should offer every feature.

PRISM Net detects hardware and only offers certain options when they make sense:
- extra disk -> Jellyfin
- GPU -> Stable Diffusion
- second NIC -> gateway mode

That keeps recommendations honest instead of pretending all boxes are identical.

## Honest Status
PRISM Net is designed and partially scaffolded, but it is not built yet.

Current status:
- architecture direction is decided
- firstboot orchestration draft exists
- setup-mode prompt exists
- setup backend draft exists
- nginx mode split exists
- MOTD banner exists

What is still incomplete:
- native service install paths need hardening
- backend and firstboot need to be aligned around real service units
- setup UI itself is not finalized here
- no Net image has been built yet
- no 7020 boot test has been done yet

That is normal.

The design is now concrete enough to build against instead of continuing to guess.
