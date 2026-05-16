# PRISM Install Blocker Diagnosis Hand - 2026-05-16

## What Was Added

Added a dedicated public-safe read-only blocker diagnosis hand for Iris:

```text
POST /setup/diagnose-install-blockers
```

Repo pieces:

- `net/ui/prism-setup-backend.py`
- `net/setup-jobs/diagnose_install_blockers.sh`
- `net/ui/index.html`
- `net/nginx/prism-iris.conf`

This hand diagnoses why a PRISM service install is blocked and suggests safe
next steps. It does not install anything.

## Why This Is Not An Install Job

This endpoint is read-only.

It does not:

- install packages
- install PRISM services
- trigger mutating setup jobs
- expose generic `/setup/jobs`
- expose install job URLs
- change files or services
- restart services
- change passwords
- change Ollama models

It reports blocker evidence only.

## Endpoint Behavior

Expected response shape:

```json
{
  "endpoint": "diagnose-install-blockers",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "service": "adguard",
  "overall": "blocked|warning|clear|unknown",
  "summary": "AdGuard is blocked because port 53 is already in use.",
  "blockers": [
    {
      "type": "port_in_use",
      "port": 53,
      "protocol": "tcp/udp",
      "owner": "systemd-resolve or unknown",
      "confidence": "high|medium|low",
      "safe_options": []
    }
  ],
  "safe_next_steps": [],
  "checks": {
    "ports": {},
    "services": {},
    "public_surface": {},
    "readiness_check": {}
  },
  "rollback_hint": "No changes made; read-only diagnosis."
}
```

Checks include:

- ports in use for `53`, `80`, `443`, `3000`, `8080`, and `8888`
- sanitized port owners from `ss`
- common blocker services:
  - `systemd-resolved`
  - `dnsmasq`
  - `named`
  - `bind9`
  - `unbound`
  - `nginx`
  - `apache2`
  - `caddy`
- systemd state for `adguardhome`, `vaultwarden`, and `searxng`
- current PRISM public-surface safety:
  - `/setup/jobs` blocked
  - `/hardware` blocked
  - `/setup/hardware` blocked
  - `/setup/state` sanitized
- whether `check-install-readiness` still reports the same blocker class

Allowed input:

```json
{ "service": "adguard" }
```

Allowed service values:

- `adguard`
- `vaultwarden`
- `searxng`
- `all`

Missing or unknown service values fall back to `all`.

## Iris Behavior

The frontend detects blocker questions such as:

- `why is adguard blocked`
- `what is using port 53`
- `diagnose install blockers`
- `what is blocking installs`

When detected, the frontend calls:

```text
POST /setup/diagnose-install-blockers
```

It injects the backend result into the Ollama chat as `PRISM_BACKEND_RESULT`
with instructions that Iris must:

- use the backend result as the only source of truth
- say `Here is what the PRISM backend reported:`
- report blocker diagnosis only
- not claim she ran commands personally
- not claim she changed services
- not invent services, files, logs, ports, job results, or command output
- present listed options as options only

If the diagnosis fails, Iris must say the diagnosis failed or was unavailable
and must not guess the blocker.

## Safety Boundaries

The backend route is dedicated:

```text
/setup/diagnose-install-blockers
```

It does not add blocker diagnosis to the generic job list.
It does not open `/setup/jobs`.
It does not expose mutating install jobs.

The nginx repo config adds only an exact-match proxy for the new endpoint.
Existing blocks remain:

- `location ^~ /setup/jobs { return 403; }`
- `location = /setup/hardware { return 403; }`
- `location = /hardware { return 403; }`

## Verification Results

Repo syntax checks:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
bash -n net/setup-jobs/diagnose_install_blockers.sh
bash -n net/setup-jobs/check_install_readiness.sh
```

All passed.

Live deployment on `192.168.14.115`:

```text
/usr/local/bin/prism-setup-backend.backup-20260516-diagnose-blockers
/var/www/prism-chat/index.html.backup-20260516-diagnose-blockers
/etc/nginx/sites-available/prism-iris.backup-20260516-diagnose-blockers
```

Live validation:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend: passed
bash -n /usr/local/lib/prism/setup-jobs/diagnose_install_blockers.sh: passed
nginx -t: passed
systemctl restart prism-setup-backend: completed
systemctl is-active prism-setup-backend: active
systemctl reload nginx: completed
systemctl is-active nginx: active
```

Public endpoint checks from MotherShip:

```text
POST /setup/diagnose-install-blockers: 200 OK
POST /setup/diagnose-install-blockers {"service":"adguard"}: 200 OK
GET /setup/jobs: 403 Forbidden
POST /setup/jobs/install_vaultwarden: 403 Forbidden
GET /setup/state: 200 OK, sanitized JSON
GET /hardware: 403 Forbidden
GET /setup/hardware: 403 Forbidden
```

Diagnosis results:

```text
generic overall: blocked
generic changed_files: []
generic changed_services: []
adguard summary: AdGuard is blocked because port 53 is already in use.
adguard changed_files: []
adguard changed_services: []
```

The live adguard diagnosis reported port 53 ownership by the local DNS stack
and returned safe next-step options only.

## Privacy Results

Value-oriented privacy checks against the live diagnosis response:

```text
raw MAC addresses present? false
disk serial values present? false
WWN values present? false
UUID-like hardware ID values present? false
/dev/disk/by-id paths present? false
password/token/cookie/private key values present? false
useful blocker diagnosis info present? true
```

## Iris Test Result

Question asked through the live stack:

```text
Why is AdGuard blocked?
```

Iris responded:

```text
Here is what the PRISM backend reported:

AdGuard is blocked because port 53 is already in use.
```

Iris did not claim an install happened.
Iris did not claim services were changed.
Iris did not trigger a mutating job.

## Service Safety

Confirmed on live 115:

- `/setup/jobs` remains `403`
- `POST /setup/jobs/install_vaultwarden` remains `403`
- no services were installed
- no mutating jobs were triggered
- changed files and changed services were empty for the diagnosis endpoint

## Next Step Toward Iris-Managed Installs

Use this blocker diagnosis hand when Iris needs to explain why an install is
blocked and what safe options exist.

The next install-related step remains a separate consent-gated install path.
This hand must stay read-only.
