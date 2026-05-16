# PRISM Hardware Endpoint Lockdown - 2026-05-15

## Summary

Normal-mode nginx on `192.168.14.115` was hardened so raw hardware endpoints are no longer public on the LAN.

No backend code was changed. No jobs were triggered. No services were installed. Only nginx was reloaded after `nginx -t` passed.

## What Was Exposed

Before this change, the public endpoints below returned raw backend hardware state:

- `/hardware`
- `/setup/hardware`

Privacy inspection found:

- Raw MAC addresses: true
- Disk serial field: true
- WWNs or WWN-like values: false
- UUID-like hardware IDs: false
- `/dev/disk/by-id` paths: false

Raw identifier values are intentionally omitted from this document.

## What Was Blocked

Normal-mode nginx now blocks:

- `/hardware`
- `/setup/hardware`
- `/setup/jobs`
- `/setup/jobs/...`

Normal-mode nginx still allows:

- `/setup/state`

Any other `/setup/...` path returns 404.

## Backup

Live nginx backup:

`/etc/nginx/sites-available/prism-iris.backup-20260515-hardware-endpoint-lockdown`

## Verification

`nginx -t` passed before reload:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Curl verification from the LAN-facing URL:

```text
GET /setup/state                         200 application/json
GET /hardware                            403 text/html
GET /setup/hardware                      403 text/html
GET /setup/jobs                          403 text/html
POST /setup/jobs/install_vaultwarden     403 text/html
```

The POST verification returned 403 at nginx. It did not trigger a backend job.

## `/setup/state` Privacy Check

The public `/setup/state` endpoint still exposes:

- Raw MAC addresses: true
- Disk serial fields: true
- WWNs or WWN-like values: false
- UUID-like hardware IDs: false
- `/dev/disk/by-id` paths: false

This means `/setup/state` is still not ideal as a public endpoint. It remains enabled only because the current frontend truth bridge depends on it.

## Iris Truth Bridge Check

The live frontend still contains:

- `sanitizePrismStateForIris(hardware)`
- `prismStateMessage(hardware)`
- `fetch("/setup/state", { method: "GET" })`

A bounded chat verification using sanitized PRISM_STATE passed:

- Iris cited `PRISM_STATE fetched from /setup/state`.
- Iris reported RAM, NIC link status, disk size, and GPU model names.
- Iris did not emit raw MAC address patterns.
- Iris did not report disk serial numbers.

## Recommended Next Fix

Add backend-level sanitized public state before relying on `/setup/state` as a LAN-public endpoint.

Recommended shape:

- Keep raw `/setup/state` localhost/internal only, or require a backend gate.
- Add a sanitized endpoint such as `/setup/public-state` for browser/Iris use.
- Redact MAC addresses, disk serials, WWNs, UUID-like hardware IDs, `/dev/disk/by-id` paths, tokens, passwords, cookies, and private keys.
- Update the frontend truth bridge to fetch the sanitized public endpoint.
- Only after that, consider blocking raw `/setup/state` through normal-mode nginx.
