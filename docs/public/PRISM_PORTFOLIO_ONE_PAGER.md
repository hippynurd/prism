# PRISM Portfolio One-Pager

## Project Summary

PRISM is a privacy-focused, local-first home server platform that turns old
office PCs, gaming desktops, and Linux boxes into understandable private
infrastructure. Iris, the local operator assistant, explains hardware,
readiness, blockers, and setup options before any system-changing action.

This is an alpha project, not a production-ready product.

## Technical Skills Demonstrated

- Linux systems architecture
- Debian-based automation
- Python backend development
- Bash automation and safety scripting
- nginx reverse proxy design
- systemd service handling
- endpoint security and public/private route design
- hardware-aware capability detection
- local AI integration through Ollama
- Git-based release discipline with tags and handoff docs
- live deployment with backups and validation
- privacy-first redaction and sanitization

## Architecture Summary

PRISM uses a small backend to expose public-safe setup facts and read-only
diagnostic endpoints. The browser UI gives Iris sanitized backend results as the
only source of truth. nginx exposes exact safe routes and blocks generic job
launch endpoints.

Current dev topology:

- MotherShip: factory/PXE/control box
- 115: live PRISM dev server
- FM09/9: temporary helper/model/build node, currently frozen

## Technologies Used

- Debian/Linux
- Python 3 standard library backend
- Bash
- nginx
- systemd
- Ollama
- HTML/CSS/JavaScript
- Git/GitHub
- SSH/SCP deployment workflow

## Problems Solved

- Built a real read-only status bridge from Linux state to Iris.
- Sanitized hardware state before exposing it publicly.
- Blocked raw hardware and generic job endpoints.
- Added readiness checks without starting installs.
- Added blocker diagnosis for install safety.
- Added AI/GPU readiness diagnostics without changing GPU settings.
- Added a capability planner that maps hardware and goals to safe
  recommendations.
- Audited and cleaned accidental PRISM MOTD contamination on MotherShip.
- Created lightweight checkpoints to avoid giant image backups during dev.

## Security And Privacy Decisions

- Do not expose `/setup/jobs` publicly.
- Do not expose raw `/hardware` or `/setup/hardware`.
- Do not print or commit secrets, raw MACs, disk serials, tokens, cookies,
  private keys, passwords, UUID-like hardware IDs, or API keys.
- Keep public endpoints read-only until a gated install flow exists.
- Treat 115 as a dev server, not a production hardcoded IP.
- Require dev SSH keys to be removed before image-clean/finalization.

## Deployment / Factory Direction

PRISM separates factory/control duties from the live dev server:

- MotherShip handles factory/PXE/control work.
- 115 runs the live PRISM dev instance.
- Deployment uses explicit target access and live backups.
- Future production work should refuse live deployment to MotherShip unless it
  is explicitly approved as the target.

## What This Says About The Architect

This project shows practical systems architecture under real-world constraints:
limited hardware, evolving requirements, security risk, deployment mistakes,
hardware variance, and the need to recover safely.

It demonstrates the ability to:

- design safety boundaries before adding power
- turn messy local infrastructure into documented workflows
- build small tools that compose into a larger platform
- ship incremental milestones with rollback notes
- keep privacy and user control central
- use AI as an operator interface without letting it invent system facts

## Resume-Ready Bullet Points

- Architected PRISM, a local-first Linux home-server platform with a browser AI
  operator assistant and read-only backend diagnostics.
- Built public-safe setup endpoints for sanitized hardware state, readiness
  checks, blocker diagnosis, AI runner readiness, and capability planning.
- Designed nginx route boundaries that expose exact safe endpoints while keeping
  generic job launch and raw hardware routes blocked.
- Implemented hardware-aware recommendations for privacy services, files/backups,
  local AI, GPU helper workloads, and factory/control-plane roles.
- Created deployment handoffs with live backups, syntax validation, endpoint
  verification, and Git milestone tags.
- Audited and remediated accidental host contamination without broad cleanup or
  unrelated system changes.

