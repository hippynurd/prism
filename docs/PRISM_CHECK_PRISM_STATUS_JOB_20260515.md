# PRISM `check_prism_status` Backend Job - 2026-05-15

## Summary

Added the first read-only PRISM backend job:

`check_prism_status`

This is Backend Hands v1: Iris can later call an approved backend job and report real backend results without claiming direct system access. This change does not expose job endpoints through public nginx.

No packages were installed. No PRISM services were installed. No mutating jobs were triggered. Ollama, models, passwords, and service install state were not changed.

## Added Paths

Repo backend:

`/vault/pve-media/projects/prism/net/ui/prism-setup-backend.py`

Repo job script:

`/vault/pve-media/projects/prism/net/setup-jobs/check_prism_status.sh`

Live backend:

`/usr/local/bin/prism-setup-backend`

Live job script:

`/usr/local/lib/prism/setup-jobs/check_prism_status.sh`

## Live Backup

Backend backup:

`/usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status`

## Job Safety Rules

The job is read-only. It may check:

- `systemctl is-active prism-setup-backend`
- `systemctl is-active nginx`
- `systemctl is-active ollama`
- PRISM marker file existence
- localhost backend `/setup/state`
- localhost backend `/setup/public-state`
- localhost Ollama model tags
- sanitized listening TCP ports
- localhost nginx status for `/setup/state` and `/setup/jobs`

The job must not:

- Install anything
- Start, stop, or restart services
- Edit files
- Run arbitrary user-provided commands
- Expose raw MAC addresses
- Expose disk serials
- Expose WWNs, UUID-like hardware IDs, `/dev/disk/by-id` paths
- Expose passwords, tokens, cookies, private keys, or API keys

## Backend Changes

The backend allowlist now includes:

```python
"check_prism_status": {
    "script": "check_prism_status.sh",
    "description": "Return a read-only sanitized PRISM status snapshot.",
}
```

The job framework now gives each job a result path:

`/var/lib/prism/jobs/<job_id>.result.json`

The script writes structured JSON to that file through `PRISM_JOB_RESULT`. `GET /setup/jobs/<job_id>` includes the sanitized result when present.

For `check_prism_status`, the backend does not call `collect_state()` after job success, so the read-only job does not refresh or rewrite setup state as a side effect.

## Structured Result

The job result includes:

- `job_name`
- `status`
- `read_only`
- `summary`
- `checks`
- `redactions`
- `changed_files`
- `changed_services`
- `rollback_hint`

The result reports:

- `prism_setup_backend` active status
- `nginx` active status
- `ollama` active status
- setup state existence and reachability
- public state privacy booleans
- PRISM marker file booleans
- installed Ollama model count and names
- sanitized listening TCP port summary
- public API status summary

## Syntax Checks

Repo checks:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
bash -n net/setup-jobs/check_prism_status.sh
```

Live checks:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend
bash -n /usr/local/lib/prism/setup-jobs/check_prism_status.sh
systemctl restart prism-setup-backend
systemctl is-active prism-setup-backend
```

Live backend reported:

```text
active
```

## Internal Job Test

Triggered only from localhost on `192.168.14.115`:

```text
POST http://127.0.0.1:5000/setup/jobs/check_prism_status
GET  http://127.0.0.1:5000/setup/jobs/<job_id>
```

Sanitized result summary:

```json
{
  "status": "succeeded",
  "exit_code": 0,
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "services": {
    "prism_setup_backend": true,
    "nginx": true,
    "ollama": true
  },
  "setup_state": {
    "exists": true,
    "public_state_reachable_locally": true,
    "public_state_via_nginx_status": 200,
    "privacy": {
      "raw_mac_addresses_present": false,
      "serial_fields_redacted": true,
      "uuid_like_ids_present": false,
      "dev_disk_by_id_paths_present": false
    }
  },
  "markers": {
    "setup_complete": true,
    "firstboot_done": true,
    "setup_mode": false
  },
  "public_api": {
    "/setup/state": "sanitized",
    "/setup/jobs": "blocked_by_nginx"
  }
}
```

## Public Nginx Block Test

Public LAN job endpoints remain blocked:

```text
GET  /setup/jobs                    403 text/html
POST /setup/jobs/check_prism_status 403 text/html
```

Public `/setup/state` remains available and sanitized:

```text
GET /setup/state 200 application/json
```

Privacy check for public `/setup/state`:

```text
raw MAC addresses present: false
unredacted disk serials present: false
UUID-like hardware IDs present: false
/dev/disk/by-id paths present: false
useful GPU/RAM/disk/NIC status present: true
```

## Iris Truth Bridge

A bounded Iris chat test through `/api/chat` using public `/setup/state` passed:

- Iris cited `PRISM_STATE fetched from /setup/state`.
- Iris reported hardware facts from PRISM_STATE.
- Iris did not emit raw MAC address patterns.
- Iris did not report disk serial numbers.

## Rollback

Rollback backend:

```bash
cp /usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status \
  /usr/local/bin/prism-setup-backend
chmod 755 /usr/local/bin/prism-setup-backend
python3 -m py_compile /usr/local/bin/prism-setup-backend
systemctl restart prism-setup-backend
systemctl is-active prism-setup-backend
```

Remove live job script if needed:

```bash
rm -f /usr/local/lib/prism/setup-jobs/check_prism_status.sh
```

## Next Step

Add backend gates before frontend/Iris job controls:

- Per-job `read_only` metadata
- Mutating-job block unless explicit setup mode is active
- Keep public nginx blocking `/setup/jobs`
- Then add the frontend/Iris call path where Iris says: "Here is what the PRISM backend reported."
