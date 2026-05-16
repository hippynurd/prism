# PRISM Job Endpoint Safety Inspection - 2026-05-15

## Scope

Read-only inspection only. No files were edited on the live PRISM target, no jobs were triggered, and no POST requests were sent to `/setup/jobs`.

Inspected:

- `/vault/pve-media/projects/prism/net/ui/prism-setup-backend.py`
- `/usr/local/bin/prism-setup-backend` on `192.168.14.115`
- `/etc/nginx/sites-available/prism-iris` on `192.168.14.115`

## Findings

### 1. Are POST `/setup/jobs/<job_name>` endpoints reachable through nginx from the LAN?

Yes, based on config inspection.

The active normal-mode nginx config listens on port 80 as the default server and has:

```nginx
location ^~ /setup/ {
    proxy_pass http://127.0.0.1:5000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Cache-Control "no-store";
}
```

Because this proxies all `/setup/` paths, `/setup/jobs/<job_name>` is reachable through nginx wherever port 80 is reachable.

### 2. Is there any authentication, token, CSRF check, localhost-only check, setup-mode check, or confirmation gate?

No.

In both the repo backend and live backend, `do_POST()` accepts `/jobs/<job_name>` and `/setup/jobs/<job_name>` if the job name is allowlisted. There is no observed check for:

- Authentication
- Authorization token
- CSRF token
- Browser origin
- Localhost-only client address
- Setup-mode marker such as `/etc/prism/setup-mode`
- Setup-complete marker gate
- User confirmation gate

The backend binds to `127.0.0.1`, but nginx exposes `/setup/` to LAN-facing port 80.

### 3. Can GET `/setup/jobs` expose sensitive job logs/results?

Partially.

Current `GET /setup/jobs` returns only the public allowlist names and descriptions.

Current `GET /setup/jobs/<job_id>` returns a receipt with:

- `job_id`
- `job_name`
- `status`
- timestamps
- `exit_code`
- `log_path`
- `metadata_path`
- `error`

It does not return full stdout or stderr in the current code. However, exposing `log_path`, `metadata_path`, job names, timing, and error strings still leaks operational details. Future structured job result support must sanitize results before returning them.

### 4. Are install jobs like `install_vaultwarden` currently callable if someone POSTs to the endpoint?

Yes, based on code and nginx inspection.

`install_vaultwarden` is present in `ALLOWED_JOBS`:

```python
"install_vaultwarden": {
    "script": "install_vaultwarden.sh",
    "description": "Install and verify Vaultwarden.",
},
```

`POST /setup/jobs/install_vaultwarden` would pass the allowlist check and call `start_job()`, which launches the configured script if it exists and is executable. This was not tested with a POST request.

### 5. Smallest Safe Gate Before Adding Iris Job Controls

Smallest safe gate:

1. Block non-read-only jobs while PRISM is in normal mode.
2. Require an explicit setup/job-control marker for mutating jobs, for example `/etc/prism/setup-mode`.
3. Allow read-only jobs such as future `check_prism_status` without permitting install jobs.
4. Add per-job metadata such as `read_only: true|false` and enforce it in `do_POST()`.
5. Do not expose mutating jobs through nginx unless the setup-mode gate is active.

Recommended minimal backend policy:

```python
ALLOWED_JOBS = {
    "probe_hardware": {"script": "probe_hardware.sh", "description": "...", "read_only": True},
    "check_prism_status": {"script": "check_prism_status.sh", "description": "...", "read_only": True},
    "install_vaultwarden": {"script": "install_vaultwarden.sh", "description": "...", "read_only": False},
}

def setup_mode_enabled() -> bool:
    return Path("/etc/prism/setup-mode").exists()

def validate_job_allowed(job_name: str) -> None:
    job = ALLOWED_JOBS[job_name]
    if not job.get("read_only", False) and not setup_mode_enabled():
        raise PermissionError("mutating job requires setup mode")
```

Recommended minimal nginx hardening for normal mode:

- Keep `/setup/state` reachable for PRISM_STATE.
- Keep `/setup/hardware` only if still needed.
- Do not proxy all `/setup/` in normal mode.
- Either block `/setup/jobs/` at nginx or let only read-only job endpoints through after backend gating exists.

Example normal-mode direction:

```nginx
location = /setup/state {
    proxy_pass http://127.0.0.1:5000/setup/state;
}

location = /setup/hardware {
    proxy_pass http://127.0.0.1:5000/setup/hardware;
}

location ^~ /setup/jobs/ {
    return 403;
}
```

This nginx-only block is a defensive layer, not a replacement for backend enforcement.

## Conclusion

The current live configuration exposes the backend job launcher through nginx on `/setup/jobs/<job_name>`. The backend has allowlisting, but no authentication, no setup-mode gate, and no read-only vs mutating job separation. Install jobs such as `install_vaultwarden` are therefore reachable by anyone who can POST to the LAN HTTP endpoint, assuming the corresponding script exists and is executable.

Before adding Iris job controls, add a backend-enforced read-only/mutating job gate and narrow normal-mode nginx exposure so `/setup/state` remains available without exposing mutating job launch endpoints.
