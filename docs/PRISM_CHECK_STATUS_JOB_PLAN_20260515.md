# PRISM `check_prism_status` Job Plan - 2026-05-15

## Goal

Design the first minimal read-only Iris tool job:

```text
check_prism_status
```

Purpose:

```text
Give Iris a real, current status snapshot from the PRISM backend.
```

Architecture boundary:

- Iris is the user-facing operator.
- PRISM backend runs approved jobs.
- Codex must not install services manually.
- Iris must not claim direct system access.
- Iris should say: `Here is what the PRISM backend reported:`

This document is design-only. No live backend, nginx, Ollama, model, password, systemd, or service changes were made while producing it.

## Inspected Files

Only these files were inspected for this design:

- Live backend: `/usr/local/bin/prism-setup-backend` on `192.168.14.115`
- Repo backend: `/vault/pve-media/projects/prism/net/ui/prism-setup-backend.py`
- Small frontend check: `/vault/pve-media/projects/prism/net/ui/index.html`
- Small live frontend check: `/var/www/prism-chat/index.html` on `192.168.14.115`

No broad directory scans or large image/build artifacts were read.

## Live Backend vs Repo Backend Differences

### Live Backend On `192.168.14.115`

Live backend identifies as:

```text
PrismSetupBackend/0.2
```

It already has an allowlisted async job framework:

- `ALLOWED_JOBS`
- `JOB_DIR = /var/lib/prism/jobs`
- `JOB_LOG_DIR = /var/log/prism-jobs`
- `SCRIPT_DIR = /usr/local/lib/prism/setup-jobs`
- `POST /jobs/<job_name>`
- `POST /setup/jobs/<job_name>`
- `GET /jobs`
- `GET /setup/jobs`
- `GET /jobs/<job_id>`
- `GET /setup/jobs/<job_id>`
- job metadata JSON under `/var/lib/prism/jobs`
- logs under `/var/log/prism-jobs`

Current live allowlisted jobs:

```text
probe_hardware
install_model
install_nvidia_runtime
enable_gpu_for_iris
reload_nginx
install_vaultwarden
mark_setup_complete
```

Live job receipts currently include:

```json
{
  "job_id": "...",
  "job_name": "...",
  "status": "queued|running|succeeded|failed",
  "created_at": "...",
  "started_at": "...",
  "finished_at": "...",
  "exit_code": 0,
  "log_path": "...",
  "metadata_path": "...",
  "error": null
}
```

The live backend does not currently return structured per-job result details, sanitized stdout/stderr, changed files, changed services, rollback hints, or redaction metadata in the receipt. It writes job output to a log file and returns only metadata.

### Repo Backend

Repo backend at `net/ui/prism-setup-backend.py` identifies as:

```text
PrismSetupBackend/0.1
```

It is older and does not have the live allowlisted job framework. It supports:

- `GET /hardware`
- `GET /state`
- `GET /progress`
- `POST /install`
- `POST /complete`

It uses an in-memory `SetupState` and installer functions. It does not support:

- `POST /setup/jobs/<job_name>`
- `GET /setup/jobs/<job_id>`
- job metadata files
- job log directory
- allowlisted script dispatch under `/usr/local/lib/prism/setup-jobs`

### Frontend Job Support

The inspected current frontend copies did not contain `setup/jobs`, `pollJob`, `runSetupAction`, `allowedJobNames`, or `jobName` references. That means the current truth-bridge frontend does not have an active UI path for starting backend jobs.

For v1, the backend can be implemented first and tested with direct HTTP. Then the frontend can add a small intent mapping for `check_prism_status`.

## Current Job Support

Live backend already has the right endpoint shape for the requested v1:

```text
POST /setup/jobs/check_prism_status
GET /setup/jobs/<job_id>
```

But the job name is not currently allowlisted. A future patch must add:

```python
"check_prism_status": {
    "script": "check_prism_status.sh",
    "description": "Return a sanitized read-only PRISM status snapshot.",
}
```

The repo backend should be updated to match the live v0.2 job framework before adding new jobs, otherwise future image builds may regress the live behavior.

## v1 Endpoint Design

### Start Job

```http
POST /setup/jobs/check_prism_status
Content-Type: application/json

{}
```

Preferred response if using current live async framework:

```json
{
  "job_id": "1760000000-abc123def456",
  "job_name": "check_prism_status",
  "status": "queued",
  "created_at": "2026-05-15T11:30:00-0700",
  "started_at": null,
  "finished_at": null,
  "exit_code": null,
  "read_only": true,
  "log_path": "/var/log/prism-jobs/1760000000-abc123def456-check_prism_status.log",
  "metadata_path": "/var/lib/prism/jobs/1760000000-abc123def456.json",
  "error": null
}
```

### Poll Job

```http
GET /setup/jobs/<job_id>
```

V1 should extend the receipt to include the structured result once available:

```json
{
  "job_name": "check_prism_status",
  "status": "succeeded",
  "read_only": true,
  "started_at": "2026-05-15T11:30:00-0700",
  "finished_at": "2026-05-15T11:30:01-0700",
  "exit_code": 0,
  "summary": "PRISM backend, nginx, and Ollama are active. Setup state is reachable and fresh.",
  "checks": {
    "prism_setup_backend": {},
    "nginx": {},
    "ollama": {},
    "setup_state": {},
    "models": {},
    "ports": {},
    "markers": {}
  },
  "stdout": "...sanitized...",
  "stderr": "...sanitized...",
  "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key"],
  "changed_files": [],
  "changed_services": [],
  "rollback_hint": "No changes made; read-only job."
}
```

### Synchronous Alternative

If keeping the first patch smaller is more important than integrating with the async job loop, a synchronous special-case endpoint could return the final object directly from:

```text
POST /setup/jobs/check_prism_status
```

However, because the live backend already has a job framework, the smallest durable design is to reuse it and add a structured result field to metadata.

## v1 Structured Result Format

Target shape:

```json
{
  "job_name": "check_prism_status",
  "status": "succeeded|failed|running",
  "read_only": true,
  "started_at": "...",
  "finished_at": "...",
  "exit_code": 0,
  "summary": "...",
  "checks": {
    "prism_setup_backend": {
      "service": "prism-setup-backend",
      "active": true,
      "source": "systemctl is-active"
    },
    "nginx": {
      "service": "nginx",
      "active": true,
      "active_site": "prism-iris",
      "source": "systemctl and /etc/nginx/sites-enabled"
    },
    "ollama": {
      "service": "ollama",
      "active": true,
      "api_reachable": true,
      "source": "systemctl and local API"
    },
    "setup_state": {
      "reachable": true,
      "freshness": "fresh|stale|unknown",
      "last_probe_timestamp": "...",
      "setup_complete": true,
      "source": "GET /setup/state"
    },
    "models": {
      "reachable": true,
      "installed": ["llama3.1:8b"],
      "recommended_model": "llama3.1:8b",
      "source": "Ollama API or ollama list"
    },
    "ports": {
      "80": "listening",
      "5000": "listening_localhost",
      "11434": "listening_localhost",
      "source": "ss -lntp"
    },
    "markers": {
      "/var/lib/prism/setup-state.json": "present",
      "/var/lib/prism/setup-complete": "present",
      "/var/lib/prism/firstboot.done": "present",
      "/etc/prism/setup-mode": "absent"
    }
  },
  "stdout": "...sanitized...",
  "stderr": "...sanitized...",
  "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key"],
  "changed_files": [],
  "changed_services": [],
  "rollback_hint": "No changes made; read-only job."
}
```

## Allowed Checks

`check_prism_status` may check only:

- `prism-setup-backend` service active/inactive
- `nginx` active/inactive
- `ollama` active/inactive
- listening ports
- configured nginx site
- `/setup/state` reachable
- `/setup/state` freshness
- current Ollama models
- marker files:
  - `/var/lib/prism/setup-state.json`
  - `/var/lib/prism/setup-complete`
  - `/var/lib/prism/firstboot.done`
  - `/etc/prism/setup-mode`

## Not Allowed

`check_prism_status` must not:

- install packages
- start, stop, reload, or restart services
- edit files
- expose raw MAC addresses
- expose disk serials
- expose WWNs
- expose UUID-like hardware IDs
- expose passwords/tokens/cookies/private keys
- run arbitrary commands provided by the model
- include environment secrets

## Sanitization Rules

Apply sanitization recursively to `stdout`, `stderr`, and `checks` before returning to Iris.

Redact:

- raw MAC addresses
- fields named `mac`, `mac_address`
- disk serials
- fields named `serial`
- WWNs
- fields named `wwn`
- UUID-like hardware IDs
- stable device IDs such as `/dev/disk/by-id`, `ata-*`, `scsi-*`, `wwn-*`, `nvme-*`, `eui.*`, `naa.*`
- strings containing `password`, `token`, `cookie`, `authorization`, `api_key`
- private key blocks such as `BEGIN OPENSSH`, `BEGIN RSA`, `BEGIN ... PRIVATE`

Use:

```text
[REDACTED]
```

## Backend Implementation Design

### Read-Only Script

Add a new script:

```text
net/setup-jobs/check_prism_status.sh
```

Installed later to:

```text
/usr/local/lib/prism/setup-jobs/check_prism_status.sh
```

The script should be fixed and allowlisted. It should not accept arbitrary command input.

It can collect raw status with known read-only commands and emit one JSON object to stdout.

Allowed command examples:

```bash
systemctl is-active prism-setup-backend
systemctl is-active nginx
systemctl is-active ollama
ss -lntp
readlink -f /etc/nginx/sites-enabled/*
curl -fsS http://127.0.0.1:5000/setup/state
curl -fsS http://127.0.0.1:11434/api/tags
test -e /var/lib/prism/setup-state.json
test -e /var/lib/prism/setup-complete
test -e /var/lib/prism/firstboot.done
test -e /etc/prism/setup-mode
```

The script should not output raw environment, raw full service status blocks, secrets, serials, or MAC addresses.

### Backend Changes

Patch repo backend after reconciling live v0.2:

```text
net/ui/prism-setup-backend.py
```

Needed changes:

1. Bring repo backend up to the live v0.2 job framework if not already done.
2. Add `check_prism_status` to `ALLOWED_JOBS`.
3. Add metadata fields:
   - `read_only`
   - `summary`
   - `checks`
   - `stdout`
   - `stderr`
   - `redactions`
   - `changed_files`
   - `changed_services`
   - `rollback_hint`
4. Teach `run_job()` to parse JSON stdout from `check_prism_status.sh` and store sanitized structured result in metadata.
5. Ensure `job_receipt()` returns the structured result when available.

### Asset Installer Changes

Patch:

```text
scripts/install-prism-net-assets.sh
```

Ensure the new setup job script is installed executable into:

```text
$ROOTFS/usr/local/lib/prism/setup-jobs/check_prism_status.sh
```

Only after the backend/repo reconciliation is complete.

## Frontend / Iris Design

Current inspected frontend did not contain active `/setup/jobs` code.

Future frontend patch should add the smallest intent path:

1. If user says `check PRISM status` or similar, do not ask Ollama to invent status.
2. POST:

   ```text
   /setup/jobs/check_prism_status
   ```

3. If async, poll:

   ```text
   /setup/jobs/<job_id>
   ```

4. Add the backend result as a system/tool-grounding message.
5. Ask Iris to render only that result.

Iris response rule:

```text
Here is what the PRISM backend reported:
```

Iris must not say:

- `I ran systemctl`
- `I checked the logs`
- `I read files`
- `I ran dmesg`

unless an explicit backend result says that exact approved job did so.

## Smallest Safe Implementation Plan

Do this in small commits:

1. **Reconcile backend first**
   - Port live v0.2 job framework into repo `net/ui/prism-setup-backend.py`.
   - Do not add new behavior yet.
   - Validate syntax and endpoint compatibility.

2. **Add read-only script**
   - Add `net/setup-jobs/check_prism_status.sh`.
   - Script emits sanitized JSON.
   - No writes, no service changes.

3. **Allowlist the job**
   - Add `check_prism_status` to `ALLOWED_JOBS`.
   - Mark it read-only in metadata.

4. **Return structured result**
   - Extend job metadata and receipt to include the structured result.
   - Keep legacy receipt fields for compatibility.

5. **Frontend trigger**
   - Add a small hardcoded intent for `check PRISM status`.
   - POST to backend job endpoint.
   - Render with `Here is what the PRISM backend reported:`.

6. **Test**
   - Direct curl start/poll test.
   - Browser test.
   - Missing backend/error test.
   - Sanitization test.

## Exact Files That Would Need Patching Later

Likely required:

```text
net/ui/prism-setup-backend.py
net/setup-jobs/check_prism_status.sh
scripts/install-prism-net-assets.sh
net/ui/index.html
```

Possibly required:

```text
scripts/validate-repo.sh
```

Only if the validator needs to include the new setup job script as a required file.

Live deployment later, after repo patch and validation:

```text
/usr/local/bin/prism-setup-backend
/usr/local/lib/prism/setup-jobs/check_prism_status.sh
/var/www/prism-chat/index.html
```

Do not deploy these until a patch has been reviewed and explicitly approved.

## Recommended First Patch

Recommended first patch is not the new job itself. It is backend reconciliation:

```text
Port live PrismSetupBackend/0.2 job framework into net/ui/prism-setup-backend.py without adding new jobs.
```

Reason:

- Live has the desired job endpoint shape already.
- Repo does not.
- Adding `check_prism_status` to the old repo backend would create a second incompatible backend design.
- Reconciliation first reduces risk and prevents future image builds from losing the live job framework.

After reconciliation, add the read-only `check_prism_status` job in a second patch.

