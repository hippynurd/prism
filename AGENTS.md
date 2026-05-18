# AGENTS.md

Standing instructions for Codex, ChatGPT, Claude, and other repo agents.

## Project Identity

PRISM is a privacy-focused, local-first home server platform.

Iris is the user-facing local operator assistant. Iris should guide setup,
status checks, blocker diagnosis, and operation from the browser.

Codex builds rails, tools, checks, docs, and implementation support. Iris should
be the installer/operator. Codex must not manually install PRISM services as the
final product path.

## Host Roles

- MotherShip is `192.168.14.1`. It is the factory, PXE, and control box.
- MotherShip must not receive live PRISM files unless explicitly approved as the
  target.
- `192.168.14.115` is the current dev PRISM server only. It is not a production
  hardcoded IP.
- Production IP is unknown. Browser code should use relative paths. Backend and
  local service calls should prefer localhost or explicit config.
- FM09/9 is a temporary helper/model/build node and is not a required PRISM
  dependency.
- Tiny Iris is frozen for now. Do not touch FM09 artifacts unless explicitly
  asked.

## Safety Rules

- Do not expose generic `/setup/jobs` publicly.
- Keep these public endpoints blocked unless explicitly redesigned and secured:
  `/hardware`, `/setup/hardware`, `/setup/jobs`, `/setup/jobs/*`.
- Do not print or commit secrets, raw MACs, disk serials, tokens, passwords,
  cookies, private keys, UUID-like hardware IDs, or API keys.
- Do not hardcode the dev host IP as a production address.
- Do not deploy, restart services, install packages, trigger jobs, or edit live
  host files unless the user explicitly requests it and confirms the target.

## Development Direction

Focus now is regular Iris plus PRISM eyes/hands on the 115 dev server.

Cleanup, image-clean, and finalization are later tasks, not active-dev tasks.
Do not clean image artifacts during normal feature work.

Before image-clean/finalization:

- remove dev SSH keys
- require a user-chosen password
- confirm no development-only credentials or host assumptions remain

