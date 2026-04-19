# PRISM

Own your server again.

**Download and build a better one. We dare you.**

![PRISM Terminal Banner](assets/prism-banner.png)
*The PRISM identity banner — displayed on every login*

## What PRISM Is
PRISM is a private, resilient, independent home server platform for people who want local services without surrendering control. It is built on Debian, designed to stay root-accessible, and meant to explain itself instead of hiding behind appliance theater.

It starts with one box. That matters. PRISM is not built around the assumption that everyone needs a cluster, a rack, or an enterprise budget. The single-server experience is the product. If local AI or heavier workloads justify expansion later, PRISM can grow into that. If not, it should still stand on its own.

PRISM is also honest about hardware. It was born on recycled Dell OptiPlex systems because those machines are cheap, available, and still useful. That does not mean PRISM is trapped there. It works on recycled hardware, old gaming PCs, and brand new machines too. The rule is simple: start with what you have, then be honest about what that hardware can really do.

## Meet Iris
Iris is the first face of PRISM.

She is not supposed to be a gatekeeper, a mascot, or a black box. She is the local guide who helps the owner understand what the machine is doing, what services are installed, where things live, and what tradeoffs matter.

PRISM should always expose three transparent ways to interact with the same system:
- Iris for guided explanation and setup
- Web GUI for visibility and daily management
- Terminal for full unrestricted control

If Iris is doing her job right, the owner ends up more informed, not more dependent.

## Two Ways To Run
### PRISM Offline
The heavier image.

It ships with the major pieces already present:
- Ollama installed
- local model already included
- nginx and Iris chat UI already staged
- larger image, faster to use once booted

This is the version for people who want a self-contained artifact and minimal download time after first boot.

### PRISM Net
The lighter image.

It starts smaller, boots faster onto hardware, and downloads what it needs on first boot while Iris guides the owner through setup in the browser.

This is the version for people who want:
- a smaller image
- hardware-aware setup
- only the services that actually make sense for the machine
- a first boot flow that stays recognizably PRISM instead of collapsing into a sterile installer

## Three Ways To Get It
### 1. Build It
Clone the repo, inspect everything, and build your own image.

This is the most PRISM way to do it.

### 2. Flash It
Download a published image, write it to disk, boot it, and let Iris take over from there.

### 3. Buy It
Buy a prebuilt PRISM machine from someone who did the hardware work already.

That path should still stay honest:
- you still get root
- you still get transparency
- you still get a machine you can inspect and change

## What Runs On PRISM
### Core Services
- Vaultwarden for passwords and credential management
- AdGuard Home for DNS and ad blocking
- Nextcloud for files, sync, contacts, calendar, and photos
- Whoogle or SearXNG for private search
- Paperless-ngx for document archive and scanning destination
- Headscale for self-hosted private coordination
- nginx and fail2ban as part of the base platform

These are not random checkboxes. They form the PRISM identity:
- private daily-use tools
- personal infrastructure
- immediate value without cloud dependence

### Optional Services
- Jellyfin when extra storage exists
- Stable Diffusion when a usable GPU exists
- Gateway mode when a second NIC exists
- Home Assistant
- Gitea
- Calibre

PRISM should stay opinionated. A smaller, better-supported service list is better than a fake marketplace full of half-finished ideas.

## Built For Real Hardware
**PRISM's niche is giving new life to end-of-life computers that might otherwise end up in a landfill — but it works fantastic on brand new hardware too.**

That is not a marketing garnish. It is part of the product philosophy.

PRISM should be honest about hardware lifecycle, honest about performance, and honest about upgrade paths. A recycled OptiPlex is a real server if the software respects its limits. An old gaming PC is a great PRISM machine if it has the GPU and RAM to justify heavier local AI. A brand new machine is also fine. The point is not nostalgia. The point is useful private computing on hardware people actually have.

## Hardware Spectrum
### Minimum Viable
- Any x86 computer
- 8GB RAM
- Core privacy services
- Small local model
- Limited, but genuinely useful

### Sweet Spot
- 32GB RAM small-form-factor machine
- Recycled Dell OptiPlex
- Full core service stack
- Strong local assistant experience
- The hardware PRISM was born on

### Power User
- Old gaming PC
- 32GB to 64GB RAM
- Usable GPU such as GTX 1070, GTX 1080, RTX 2070+, RTX 3090
- Faster inference
- Local image generation
- Better media transcoding

### High End
- 64GB RAM or more
- Modern high-end GPU
- Full-speed local AI
- Best PRISM experience with the fewest compromises

## Philosophy
PRISM should never become a black box.

The point is not to trap people inside a branded appliance. The point is to give them a polished private server that still feels like theirs.

Principles:
- No telemetry
- Full root access always
- Built on Debian
- Fully open source
- Local-first services
- Honest hardware expectations
- Explain the why, not just the what

The tone matters too:
- direct
- honest
- warm
- never corporate
- never sterile

The guiding line is still the right one:

> Leave people less ignorant, or at least entertained.

## Status

| Component | Status | Notes |
| --- | --- | --- |
| PRISM Offline v0.1 | Complete | Image built, verified, compressed, checksummed |
| Offline boot test in VM | Pending | Not yet done |
| PRISM Net architecture | Complete | First boot flow, prompt, backend, nginx split, UI direction defined |
| PRISM Net image build | Pending | Ready to build next |
| Native service installers | In progress | Needed for real first-boot Net provisioning |
| GitHub publication | In progress | README and repo scaffolding underway |

## Author
PRISM is being built by [hippynurd](https://github.com/hippynurd).

This project comes out of real infrastructure work, recycled hardware, lab experimentation, and a refusal to accept that private computing has to be ugly, locked down, or cloud-dependent.

If you can build a better one, do it.
Then show your work.
