# PRISM Screenshot / GIF Shotlist

Needed public visuals for GitHub, portfolio, and community posts.

## Core UI

- Iris first boot intro
- normal Iris chat mode
- PRISM banner / identity screen
- system state sidebar
- hardware summary

## Backend Truth / Read-Only Hands

- "Check PRISM status"
- "Are we ready to install services?"
- "Why is AdGuard blocked?"
- "Can this machine use GPUs for local AI helpers?"
- "What can this PRISM box do?"

## Safety Proof

- `/setup/jobs` returning `403 Forbidden`
- `/setup/jobs/install_vaultwarden` returning `403 Forbidden`
- `/hardware` returning `403 Forbidden`
- `/setup/state` returning sanitized JSON
- capability planner response showing `read_only: true`, `changed_files: []`,
  and `changed_services: []`

## Hardware / Capability Story

- old office PC profile: privacy basics, files/backups, private search
- old gaming PC profile: local AI/helper runner, optional image generation
- storage-heavy profile: files/backups/media/archive
- multi-GPU profile: local AI/helper/coding agent candidate
- weak machine profile: lightweight services now, Tiny Iris later

## Architecture Diagram Idea

Create a simple diagram with:

- User browser
- Iris UI
- nginx exact public-safe routes
- PRISM setup backend
- read-only checks
- blocked generic `/setup/jobs`
- blocked raw hardware endpoints
- Ollama/local AI as an optional internal service
- MotherShip as factory/PXE/control
- 115 as current dev PRISM server

Diagram note:

- Avoid raw IPs in public diagrams except where explicitly explaining dev
  topology.
- Mark 115 as "current dev server", not production architecture.

## GIF Ideas

- User asks: "What can this PRISM box do?"
- Iris replies from backend result and asks goals.
- User asks: "Why is AdGuard blocked?"
- Iris explains port 53 blocker without installing anything.
- User asks: "Can this use GPUs for local AI helpers?"
- Iris distinguishes Iris/operator model from helper/runner models.

