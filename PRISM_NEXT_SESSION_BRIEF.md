# PRISM Next Session Brief

Current server: `192.168.14.115`
Mothership: `192.168.14.1`

Current good tag: `iris-status-loop-v1-20260515`
Current HEAD: `6b20cc247224944f23fc729ef6715b43e261e246`

What works:

- Iris truth bridge is working.
- Public `/setup/state` returns sanitized PRISM state.
- Frontend injects grounded `PRISM_STATE`.
- Missing-state fallback tells Iris not to invent local facts.
- Public `POST /setup/check-prism-status` works as the first public-safe read-only Iris hand.
- Frontend calls that status endpoint only for clear status/health questions.
- Iris answers status prompts with: "Here is what the PRISM backend reported:"
- `/hardware` and `/setup/hardware` are blocked.
- `/setup/jobs` and `/setup/jobs/...` are blocked publicly.

What is blocked for safety:

- Generic public job runner access.
- Mutating job URLs such as `install_vaultwarden`.
- Raw hardware endpoints.
- Raw MACs, disk serials, WWNs, UUID-like IDs, and stable device IDs in public/Iris state.

What is not done:

- MOTD color/banner fix.
- Verified GPU assignment fields in `PRISM_STATE`.
- Agent/runner GPU assignment reporting.
- Next read-only Iris hand.
- Gated install flow through backend jobs.
- Public mutating job controls.

Architecture boundary:

Codex must not install PRISM services directly on `192.168.14.115`. Iris should install/manage services only through verified PRISM backend jobs after proper gates exist.

Recommended next task:

Fix the MOTD color/banner issue, then improve `PRISM_STATE` GPU assignment fields. Do not expose generic `/setup/jobs` publicly.

Checkpoint:

`/vault/pve-media/projects/prism/checkpoints/20260515-end-of-session/`

Archive:

`/vault/pve-media/projects/prism/checkpoints/prism-end-of-session-20260515.tar.gz`
