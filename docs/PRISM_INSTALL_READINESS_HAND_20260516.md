# PRISM Install Readiness Hand - 2026-05-16

## What Was Added

Added a dedicated public-safe read-only install readiness hand for Iris:

```text
POST /setup/check-install-readiness
```

Repo pieces:

- `net/ui/prism-setup-backend.py`
- `net/setup-jobs/check_install_readiness.sh`
- `net/ui/index.html`
- `net/nginx/prism-iris.conf`
- `scripts/install-prism-net-assets.sh`

The endpoint is designed to answer:

```text
Are we ready to install PRISM services?
```

Initial services assessed:

- AdGuard Home
- Vaultwarden
- SearXNG

## Why This Is Not An Install Job

This endpoint is read-only.

It does not:

- install packages
- install PRISM services
- pull or delete Ollama models
- trigger mutating setup jobs
- expose generic `/setup/jobs`
- expose install job URLs
- change files or services
- change passwords
- restart services

It returns readiness data only. Iris can report the result and ask the user what
they want to do next.

## Endpoint Behavior

Approximate response shape:

```json
{
  "endpoint": "check-install-readiness",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "overall": "ready|blocked|warning",
  "summary": "Install readiness check completed without making changes.",
  "checks": {
    "system": {},
    "security_surface": {},
    "ports": {},
    "services": {},
    "models": {},
    "markers": {}
  },
  "service_readiness": {
    "adguard": {
      "status": "ready|blocked|warning|unknown",
      "reasons": []
    },
    "vaultwarden": {
      "status": "ready|blocked|warning|unknown",
      "reasons": []
    },
    "searxng": {
      "status": "ready|blocked|warning|unknown",
      "reasons": []
    }
  },
  "next_step": "No install was performed. Iris may ask the user which service to prepare next.",
  "rollback_hint": "No changes made; read-only check."
}
```

Checks include:

- root disk free space
- RAM availability
- apt/dpkg lock status
- nginx active state
- `prism-setup-backend` active state
- Ollama active state
- `/setup/state` reachability and sanitization
- `/setup/jobs` blocked state
- `/hardware` blocked state
- `/setup/hardware` blocked state
- likely AdGuard ports `53` and `3000`
- service/process/unit presence for AdGuard Home, Vaultwarden, and SearXNG
- setup markers
- checkpoint/rollback directory presence
- Ollama model list and experimental model warning
- metadata-only Ollama storage size and manifest timestamps

## Iris Behavior

The frontend detects install-readiness questions such as:

- `are we ready to install services`
- `can we install adguard`
- `is vaultwarden ready to install`
- `check install readiness`
- `are installs ready`

When detected, the frontend calls:

```text
POST /setup/check-install-readiness
```

It injects the backend result into the Ollama chat as `PRISM_BACKEND_RESULT`
with instructions that Iris must:

- use the backend result as the only source of truth
- say `Here is what the PRISM backend reported:`
- report readiness only
- not claim an install happened
- not claim she personally ran commands
- not invent services, files, logs, ports, job results, or command output
- ask what the user wants to do next if installation appears possible

If the readiness check fails, Iris must say the readiness check failed or was
unavailable and must not guess readiness.

## Safety Boundaries

The backend route is dedicated:

```text
/setup/check-install-readiness
```

It does not add the readiness hand to the generic job list. It does not expose
arbitrary job names. It does not open `/setup/jobs`.

The nginx repo config adds only an exact-match proxy for the new endpoint.
Existing blocks remain:

- `location ^~ /setup/jobs { return 403; }`
- `location = /setup/hardware { return 403; }`
- `location = /hardware { return 403; }`

## Verification Results

Repo syntax checks:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
bash -n net/setup-jobs/check_install_readiness.sh
bash -n scripts/install-prism-net-assets.sh
```

All passed.

Backend function smoke test with repo script:

```text
endpoint: check-install-readiness
read_only: true
overall: blocked
changed_files: []
changed_services: []
service_readiness keys: adguard, searxng, vaultwarden
```

Standalone script smoke test:

```text
check_install_readiness completed read-only install readiness collection
```

The local smoke test ran on `MotherShip`, not on `192.168.14.115`, so local
service status and endpoint status are not PRISM 115 deployment evidence.

## Privacy Results

Value-oriented privacy checks against the generated readiness JSON:

```text
raw MAC addresses present? false
disk serial values present? false
WWN values present? false
UUID-like hardware ID values present? false
/dev/disk/by-id paths present? false
password/token/cookie/private key values present? false
useful readiness info present? true
```

The JSON includes a `redactions` policy list naming categories such as `token`
and `password`; those labels are not secret values.

## Live Deployment Status

Live deployment completed on `192.168.14.115`.

Deployed files:

- `net/ui/prism-setup-backend.py` to `/usr/local/bin/prism-setup-backend`
- `net/setup-jobs/check_install_readiness.sh` to
  `/usr/local/lib/prism/setup-jobs/check_install_readiness.sh`
- `net/ui/index.html` to `/var/www/prism-chat/index.html`
- `net/nginx/prism-iris.conf` to `/etc/nginx/sites-available/prism-iris`

Live backups created before replacement:

```text
/usr/local/bin/prism-setup-backend.backup-20260516-install-readiness
/var/www/prism-chat/index.html.backup-20260516-install-readiness
/etc/nginx/sites-available/prism-iris.backup-20260516-install-readiness
```

Live validation:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend: passed
bash -n /usr/local/lib/prism/setup-jobs/check_install_readiness.sh: passed
nginx -t: passed
systemctl restart prism-setup-backend: completed
systemctl is-active prism-setup-backend: active
systemctl reload nginx: completed
systemctl is-active nginx: active
```

No packages were installed. No PRISM services were installed. No mutating setup
jobs were triggered. No models were changed. No passwords were changed.

## Live Verification

Public endpoint checks from MotherShip:

```text
POST /setup/check-install-readiness: 200 OK
GET /setup/jobs: 403 Forbidden
POST /setup/jobs/install_vaultwarden: 403 Forbidden
GET /setup/state: 200 OK, sanitized JSON
GET /hardware: 403 Forbidden
GET /setup/hardware: 403 Forbidden
```

Readiness result:

```text
endpoint: check-install-readiness
read_only: true
overall: warning
changed_files: []
changed_services: []
adguard status: blocked
vaultwarden status: ready
searxng status: ready
```

AdGuard is blocked by the readiness check because port `53` is already in use.
No install was performed.

Live privacy check against the readiness response:

```text
raw MAC addresses present? false
disk serial values present? false
WWN values present? false
UUID-like hardware ID values present? false
/dev/disk/by-id paths present? false
password/token/cookie/private key values present? false
useful readiness info present? true
```

Live frontend check:

```text
The served Iris UI includes isInstallReadinessQuestion, calls
POST /setup/check-install-readiness, and injects the required
"Here is what the PRISM backend reported:" instruction.
```

Iris-style live API test with the user question `Are we ready to install
AdGuard?`:

```text
Iris began with "Here is what the PRISM backend reported:"
Iris reported readiness only.
Iris did not claim AdGuard was installed.
Iris did not trigger an install job.
Iris reported AdGuard blocked because port 53 is in use.
```

Service-install confirmation:

```text
adguard units/processes: 0
AdGuardHome units/processes: 0
vaultwarden units/processes: 0
searxng units/processes: 0
recent install job records in the last 20 minutes: 0
```

## Next Step Toward Iris-Managed Installs

Deploy and verify this read-only hand first.

Only after Iris can reliably report install readiness should PRISM add a
separate, explicit, confirmation-gated install preparation path. This readiness
hand should remain read-only and should not become a mutating install job.
