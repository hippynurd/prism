# PRISM Next Session Brief

Current live PRISM target:

```text
192.168.14.115
```

Mothership:

```text
192.168.14.1
```

Current state:

- Iris truth bridge is working.
- Browser `/setup/state` reaches the backend through nginx and returns JSON.
- Frontend injects sanitized `PRISM_STATE` into the Ollama messages array.
- Raw `/setup/state` remains unchanged for backend/internal use.
- Disk serials, MAC addresses, WWNs, UUID-like IDs, and stable device IDs are redacted before Iris sees state.
- If PRISM state is unavailable, the frontend injects a strong unavailable-state message so Iris refuses to invent local facts.

Latest known-good commit:

```text
25406f3b987848bccd619a1468e190d2331823f1
```

Known truth-bridge tags:

```text
truth-bridge-working-20260515
truth-bridge-sanitized-20260515
truth-bridge-missing-state-20260515
```

Checkpoint directory:

```text
/vault/pve-media/projects/prism/checkpoints/20260515-truth-bridge/
```

Documentation:

```text
/vault/pve-media/projects/prism/docs/PRISM_TRUTH_BRIDGE_20260515.md
```

Important architecture boundary:

Codex must not install PRISM services directly on `192.168.14.115`.

Iris is supposed to install and manage services through PRISM's verified backend/job system. Do not bypass Iris by manually installing Vaultwarden, AdGuard, SearXNG, Nextcloud, Paperless, Headscale, Jellyfin, or other PRISM services with Codex.

Still not done:

- real Iris job execution through verified backend workflow
- `iris-tool`
- backend job result loop
- core service installs through Iris/backend jobs
- service status reporting
- repo/live backend reconciliation

Recommended next steps:

1. Compare live `/usr/local/bin/prism-setup-backend` behavior to repo `net/ui/prism-setup-backend.py` without exposing secrets.
2. Reconcile the backend job API into the repo.
3. Define backend response schema for job start, job progress, job result, and service status.
4. Add source-labeled job result messages for Iris.
5. Add read-only service status endpoint.
6. Test Iris starting a harmless read-only job first.
7. Only after the job result loop is verified, test service installs through Iris/backend jobs.

Do not change nginx, backend, Ollama, models, passwords, systemd units, or services unless the next task explicitly requests it.

