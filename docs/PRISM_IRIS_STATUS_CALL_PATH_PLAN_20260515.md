# PRISM Iris Status Call Path Plan - 2026-05-15

## Goal

Design the smallest safe public API path that lets Iris request a real read-only PRISM status snapshot without exposing generic `/setup/jobs` or any mutating jobs.

Current safe baseline:

- Internal localhost `POST /setup/jobs/check_prism_status` works.
- Public nginx blocks `/setup/jobs` and `/setup/jobs/...`.
- Public `/setup/state` is sanitized and works.
- Raw `/hardware` and `/setup/hardware` are blocked.
- Baseline tag: `backend-hands-v1-internal-20260515`

## Recommendation

Choose option **B**:

Add a dedicated endpoint:

`POST /setup/check-prism-status`

This endpoint should run only the existing read-only `check_prism_status` path and return sanitized structured JSON.

Although option B suggested `GET`, use `POST` for the implementation because the endpoint performs live work. The operation is read-only, but it has side effects in the job system: it creates job metadata/log/result files. `GET` should not create job records.

## Option Comparison

### A. Expose exact `POST /setup/jobs/check_prism_status`

Not recommended.

Pros:

- Small nginx-only exposure.
- Reuses the existing job endpoint directly.

Cons:

- Publicly exposes the job framework URL shape.
- Increases chance of future nginx pattern mistakes exposing `/setup/jobs/<mutating_job>`.
- Frontend/Iris would learn to call generic job infrastructure.
- Harder to explain the security boundary: "jobs are blocked, except this one job URL."

### B. Add dedicated `POST /setup/check-prism-status`

Recommended.

Pros:

- Public API exposes one purpose-built read-only capability.
- Generic `/setup/jobs` remains completely blocked at nginx.
- Frontend/Iris does not learn or depend on generic job paths.
- Backend can internally reuse `check_prism_status` script/result format.
- Clear user-facing semantics: "ask PRISM backend for current status."

Cons:

- Requires a small backend route addition.
- Needs a small frontend call path later.

### C. Add dedicated `POST /setup/read-only/check_prism_status`

Acceptable but not preferred.

Pros:

- Explicit read-only namespace.
- Avoids exposing generic `/setup/jobs`.

Cons:

- More framework-shaped than needed for one first public capability.
- Creates a second mini job namespace before the security policy is fully designed.
- Easier to grow accidentally into a public multi-job surface.

### D. Do not expose any job endpoint yet

Safest short-term, but blocks the next Iris milestone.

Pros:

- No new public route.
- Maintains the current security baseline.

Cons:

- Iris cannot request verified live PRISM status from the browser.
- Delays testing the "Iris asks backend, backend reports result" loop.

## Exact Route

Public browser route:

`POST /setup/check-prism-status`

Backend internal implementation may use either:

- Direct helper function that runs the existing `check_prism_status.sh` synchronously and returns its sanitized result.
- Or a private wrapper around `start_job("check_prism_status", {})` that waits briefly for completion and returns the job receipt/result.

For v1, prefer synchronous wait with a short timeout because the script is small and read-only. If it times out, return a clear structured `running` or `failed` response.

## Nginx Exposure

Normal-mode nginx should expose only this exact route:

```nginx
location = /setup/check-prism-status {
    proxy_pass http://127.0.0.1:5000/setup/check-prism-status;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Cache-Control "no-store";
}
```

Keep the existing blocks:

```nginx
location ^~ /setup/jobs {
    return 403;
}

location = /hardware {
    return 403;
}

location = /setup/hardware {
    return 403;
}

location ^~ /setup/ {
    return 404;
}
```

Order matters: the exact `/setup/check-prism-status` location must appear before the broad `/setup/` 404 block. Generic `/setup/jobs` must remain blocked.

## Live Job vs Cached Status

For v1, run the read-only check live.

Reasoning:

- The user intent is "Check PRISM status."
- Cached status risks stale service and port data.
- The script is bounded and read-only.
- The backend already records job metadata/results for auditability.

If runtime becomes too slow, add a short cache later with a visible `generated_at` timestamp and max age, for example 10 to 30 seconds.

## Expected JSON Shape

The public endpoint should return sanitized structured JSON, not raw logs:

```json
{
  "job_name": "check_prism_status",
  "status": "succeeded",
  "read_only": true,
  "started_at": "2026-05-15T...",
  "finished_at": "2026-05-15T...",
  "exit_code": 0,
  "summary": "Read-only PRISM status snapshot collected by approved backend job.",
  "checks": {
    "prism_setup_backend": {"active": true, "state": "active"},
    "nginx": {"active": true, "state": "active"},
    "ollama": {"active": true, "state": "active"},
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
    "models": {"reachable": true, "count": 1, "models": ["llama3.1:8b"]},
    "ports": {"available": true, "listeners": [{"proto": "tcp", "port": 80}]},
    "markers": {
      "setup_complete": true,
      "firstboot_done": true,
      "setup_mode": false
    },
    "public_api": {
      "/setup/state": "sanitized",
      "/setup/jobs": "blocked_by_nginx"
    }
  },
  "redactions": ["mac", "serial", "wwn", "uuid", "token", "password", "cookie", "private_key", "api_key"],
  "changed_files": [],
  "changed_services": [],
  "rollback_hint": "No changes made; read-only job."
}
```

Do not return full raw stdout/stderr to the browser in v1. If included at all, keep them empty or sanitized.

## Frontend/Iris Behavior

When the user asks:

`Check PRISM status.`

The frontend should:

1. Call `POST /setup/check-prism-status`.
2. Add a system/developer-style message containing the returned sanitized JSON.
3. Add an instruction:

```text
Here is the verified PRISM backend result for check_prism_status.
You may only report facts from this result.
Do not claim you personally ran commands.
Say: "Here is what the PRISM backend reported:"
If a field is missing, say it was not reported by the backend.
```

Iris response should begin:

`Here is what the PRISM backend reported:`

Iris must not say:

- "I ran systemctl"
- "I checked the files"
- "I read the logs"
- "I ran nvidia-smi"

Unless the backend result explicitly contains that as a verified job output, and even then Iris should attribute it to the backend.

## Security Risks

Remaining risks:

- Public route can be spammed, causing repeated read-only status jobs and job metadata/log files.
- The endpoint reveals service status and listening port numbers to LAN clients.
- A future script change could accidentally include sensitive output.
- The route is unauthenticated on the LAN.

Mitigations for v1:

- Expose only exact `/setup/check-prism-status`.
- Keep `/setup/jobs` blocked.
- Keep mutating jobs inaccessible from nginx.
- Return sanitized structured JSON only.
- Keep `changed_files: []` and `changed_services: []`.
- Add a short backend timeout.
- Consider basic rate limiting later.
- Consider a local UI token later if PRISM becomes multi-user or exposed beyond the trusted LAN.

## Rollback Plan

Rollback nginx:

```bash
cp /etc/nginx/sites-available/prism-iris.backup-<timestamp> \
  /etc/nginx/sites-available/prism-iris
nginx -t
systemctl reload nginx
```

Rollback backend:

```bash
cp /usr/local/bin/prism-setup-backend.backup-<timestamp> \
  /usr/local/bin/prism-setup-backend
chmod 755 /usr/local/bin/prism-setup-backend
python3 -m py_compile /usr/local/bin/prism-setup-backend
systemctl restart prism-setup-backend
systemctl is-active prism-setup-backend
```

Frontend rollback:

```bash
cp /var/www/prism-chat/index.html.<backup> /var/www/prism-chat/index.html
```

Only needed if the later frontend call path is deployed.

## Test Plan

Backend syntax:

```bash
python3 -m py_compile /vault/pve-media/projects/prism/net/ui/prism-setup-backend.py
bash -n /vault/pve-media/projects/prism/net/setup-jobs/check_prism_status.sh
```

Internal route:

```bash
curl -si -X POST http://127.0.0.1:5000/setup/check-prism-status | head -40
```

Public route:

```bash
curl -si -X POST http://192.168.14.115/setup/check-prism-status | head -40
```

Public blocks:

```bash
curl -si http://192.168.14.115/setup/jobs | head -20
curl -si -X POST http://192.168.14.115/setup/jobs/check_prism_status | head -20
curl -si -X POST http://192.168.14.115/setup/jobs/install_vaultwarden | head -20
```

Expected:

- `/setup/check-prism-status` returns 200 JSON.
- `/setup/jobs` returns 403.
- `/setup/jobs/check_prism_status` returns 403.
- `/setup/jobs/install_vaultwarden` returns 403.

Privacy checks:

- No raw MAC addresses.
- No unredacted disk serials.
- No WWNs.
- No UUID-like hardware IDs.
- No `/dev/disk/by-id` paths.
- No passwords, tokens, cookies, private keys, or API keys.

Iris test:

1. Ask: `Check PRISM status.`
2. Confirm Iris says: `Here is what the PRISM backend reported:`
3. Confirm Iris reports service/status facts from the returned JSON.
4. Confirm Iris does not claim direct command execution.
5. Confirm Iris does not expose raw identifiers.

## Files To Patch Later

Backend:

`/vault/pve-media/projects/prism/net/ui/prism-setup-backend.py`

Normal-mode nginx repo config:

`/vault/pve-media/projects/prism/net/nginx/prism-iris.conf`

Live backend:

`/usr/local/bin/prism-setup-backend`

Live nginx:

`/etc/nginx/sites-available/prism-iris`

Frontend, only after backend route is ready:

`/vault/pve-media/projects/prism/net/ui/index.html`

Live frontend:

`/var/www/prism-chat/index.html`

## Implementation Result

Implemented in commit pending at the time of this note.

Public route:

`POST /setup/check-prism-status`

Backend behavior:

- Starts only the existing read-only `check_prism_status` job.
- Waits briefly for completion.
- Returns sanitized structured JSON directly to the caller.
- Does not accept or expose arbitrary `job_name`.
- Does not expose generic job infrastructure through this route.
- Does not return raw job stdout/stderr.

Normal-mode nginx behavior:

- `POST /setup/check-prism-status` proxies to the backend.
- `/setup/jobs` remains blocked.
- `/setup/jobs/...` remains blocked.
- `/setup/state` remains sanitized JSON.
- `/hardware` remains blocked.
- `/setup/hardware` remains blocked.
- Broad `/setup/` remains blocked.

Frontend/Iris UI is not wired to call this endpoint yet.

## Implementation Backups

Backend backup:

`/usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status-public-endpoint`

Nginx backup:

`/etc/nginx/sites-available/prism-iris.backup-20260515-check-prism-status-public-endpoint`

## Implementation Verification

Backend syntax check passed:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
```

Live backend syntax check passed before restart:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend
```

Live backend status after restart:

```text
active
```

Nginx validation passed before reload:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Curl verification:

```text
POST /setup/check-prism-status             200 application/json
GET  /setup/jobs                          403 text/html
POST /setup/jobs/check_prism_status       403 text/html
POST /setup/jobs/install_vaultwarden      403 text/html
GET  /setup/state                         200 application/json
GET  /hardware                            403 text/html
GET  /setup/hardware                      403 text/html
```

Sanitized public status summary:

```json
{
  "job_name": "check_prism_status",
  "status": "succeeded",
  "read_only": true,
  "exit_code": 0,
  "changed_files": [],
  "changed_services": [],
  "services": {
    "prism_setup_backend": true,
    "nginx": true,
    "ollama": true
  },
  "public_api": {
    "/setup/state": "sanitized",
    "/setup/jobs": "blocked_by_nginx"
  }
}
```

Privacy check for `POST /setup/check-prism-status`:

```text
raw MAC addresses present: false
disk serials present: false
WWNs present: false
UUID-like hardware IDs present: false
/dev/disk/by-id paths present: false
passwords/tokens/cookies/private keys present: false
useful service/status information present: true
```

Privacy check for public `/setup/state` after the change:

```text
raw MAC addresses present: false
disk serials present: false
WWNs present: false
UUID-like hardware IDs present: false
/dev/disk/by-id paths present: false
passwords/tokens/cookies/private keys present: false
useful state information present: true
```

## Implementation Rollback Commands

Rollback backend:

```bash
cp /usr/local/bin/prism-setup-backend.backup-20260515-check-prism-status-public-endpoint \
  /usr/local/bin/prism-setup-backend
chmod 755 /usr/local/bin/prism-setup-backend
python3 -m py_compile /usr/local/bin/prism-setup-backend
systemctl restart prism-setup-backend
systemctl is-active prism-setup-backend
```

Rollback nginx:

```bash
cp /etc/nginx/sites-available/prism-iris.backup-20260515-check-prism-status-public-endpoint \
  /etc/nginx/sites-available/prism-iris
nginx -t
systemctl reload nginx
```
