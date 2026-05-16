# PRISM End-of-Session Checkpoint - 2026-05-15

## Summary

Known-good milestone:

- HEAD: `6b20cc247224944f23fc729ef6715b43e261e246`
- Tag: `iris-status-loop-v1-20260515`
- Live PRISM target: `192.168.14.115`
- Mothership: `192.168.14.1`

Today locked in the PRISM/Iris truth bridge and added the first safe read-only Iris hand.

## Accomplished Today

- Reconciled the live backend job framework into the repo.
- Documented job endpoint exposure risk.
- Blocked public generic `/setup/jobs` and mutating job URLs in normal-mode nginx.
- Blocked raw public hardware endpoints:
  - `/hardware`
  - `/setup/hardware`
- Added sanitized public PRISM state:
  - Browser URL `/setup/state` now returns sanitized state.
  - Raw backend state remains internal for backend/root use.
- Added internal read-only backend job:
  - `check_prism_status`
- Added public-safe dedicated status endpoint:
  - `POST /setup/check-prism-status`
- Added frontend Iris status loop:
  - Clear status questions cause the frontend to call the read-only status endpoint.
  - Iris receives `PRISM_BACKEND_RESULT`.
  - Iris is instructed to say: "Here is what the PRISM backend reported:"
- Verified `/setup/jobs` remains blocked publicly.

## Current Tags

Relevant tags from this session:

- `working-browser-20260515`
- `truth-bridge-working-20260515`
- `truth-bridge-sanitized-20260515`
- `truth-bridge-missing-state-20260515`
- `secure-truth-bridge-20260515`
- `backend-hands-v1-internal-20260515`
- `backend-hands-v1-public-status-20260515`
- `iris-status-loop-v1-20260515`

## Iris Truth Bridge Status

Working.

The frontend still fetches `/setup/state`, receives sanitized PRISM state, and injects grounded state into the Ollama message array. Missing-state fallback remains in place so Iris should refuse to invent local hardware/service facts if state is unavailable.

## Public State Sanitizer Status

Working.

Public `/setup/state` remains available and sanitized.

Checkpoint privacy status:

```text
raw MAC addresses present: false
unredacted disk serials present: false
UUID-like hardware IDs present: false
[REDACTED_BY_ID_PATH] paths present: false
useful state information present: true
```

## Blocked Endpoints

Normal-mode nginx blocks:

- `GET /setup/jobs`
- `POST /setup/jobs/check_prism_status`
- `POST /setup/jobs/install_vaultwarden`
- `GET /hardware`
- `GET /setup/hardware`
- broad `/setup/...` paths except exact allowed routes

Allowed public routes:

- `GET /setup/state`
- `POST /setup/check-prism-status`
- `/api/...` proxy to local Ollama

Do not expose generic `/setup/jobs` publicly.

## Read-Only Status Endpoint Status

Working.

`POST /setup/check-prism-status` returns sanitized structured JSON from the read-only backend job.

Checkpoint summary:

```text
job_name: check_prism_status
status: succeeded
read_only: true
changed_files: []
changed_services: []
prism_setup_backend active: true
nginx active: true
ollama active: true
/setup/state: sanitized
/setup/jobs: blocked_by_nginx
```

## Frontend Iris Status Loop Status

Working.

Clear prompts such as `Check PRISM status.` cause the frontend to call:

`POST /setup/check-prism-status`

The frontend injects the sanitized backend result into the Ollama messages. Iris answered with a human-readable backend report and did not emit raw identifiers.

## Checkpoint Paths

Checkpoint directory:

`/vault/pve-media/projects/prism/checkpoints/20260515-end-of-session/`

Archive:

`/vault/pve-media/projects/prism/checkpoints/prism-end-of-session-20260515.tar.gz`

Archive size at creation:

`21K`

Checkpoint contents are small text/config/status files only.

## Rollback Notes

Frontend rollback backup:

`/var/www/prism-chat/index.html.backup-20260515-iris-status-call-path`

Backend public status endpoint backup:

`/usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status-public-endpoint`

Nginx public status endpoint backup:

`/etc/nginx/sites-available/prism-iris.backup-20260515-check-prism-status-public-endpoint`

Backend internal status job backup:

`/usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status`

Use rollback only if the next session explicitly decides to revert. Validate backend syntax with `python3 -m py_compile` and nginx syntax with `nginx -t` before restarting/reloading.

## What Not To Do Next

- Do not install services manually with Codex.
- Do not expose generic `/setup/jobs` publicly.
- Do not trigger mutating jobs.
- Do not install Vaultwarden, AdGuard, SearXNG, Nextcloud, Paperless, Headscale, Jellyfin, or other services outside the verified PRISM job flow.
- Do not change Ollama, models, passwords, systemd units, or nginx unless the next task explicitly requires it.
- Do not print or commit raw MACs, disk serials, UUID-like hardware IDs, tokens, passwords, cookies, private keys, or API keys.

## Recommended Next Tasks

1. Fix the MOTD color/banner issue.
2. Improve `PRISM_STATE` GPU assignment fields:
   - GPUs detected from `gpu_devices`
   - Iris/Ollama GPU assignment not yet verified in PRISM_STATE
   - agent/runner GPU assignment not yet verified in PRISM_STATE
3. Design the next read-only Iris hand.
4. Only later design install flow through gated backend jobs.
5. Add backend gates for mutating jobs before any install flow:
   - per-job `read_only` metadata
   - setup-mode gate
   - no public generic `/setup/jobs`
