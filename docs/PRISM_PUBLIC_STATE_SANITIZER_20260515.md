# PRISM Public State Sanitizer - 2026-05-15

## Summary

Public `/setup/state` now returns sanitized PRISM state while the backend still keeps raw state available internally on localhost.

No services were installed. No jobs were triggered. Ollama, models, passwords, and service install state were not changed.

## What Leaked Before

Before this fix, public `GET /setup/state` exposed raw backend setup state through normal-mode nginx.

Privacy inspection found:

- Raw MAC addresses: true
- Disk serial fields: true
- WWNs or WWN-like values: false
- UUID-like hardware IDs: false
- `/dev/disk/by-id` paths: false

Raw identifier values are intentionally omitted from this document.

## Sanitized Endpoint

Backend endpoint added:

`GET /setup/public-state`

The endpoint returns `collect_state()` after recursive sanitization. It preserves useful hardware and setup facts while redacting stable identifiers and secrets.

Redacted by default:

- `serial`
- `mac`
- `mac_address`
- `wwn`
- `uuid`
- `by_id`
- `address` values that look like MAC addresses
- `id` values that look like stable hardware identifiers
- string values containing `/dev/disk/by-id`
- UUID-looking string values
- password, token, cookie, private key, and API-key-looking values

Redaction value:

`[REDACTED]`

## Nginx Route Behavior

The browser-facing URL remains unchanged:

`GET /setup/state`

Normal-mode nginx now proxies that URL to the sanitized backend endpoint:

```nginx
location = /setup/state {
    proxy_pass http://127.0.0.1:5000/setup/public-state;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Cache-Control "no-store";
}
```

Still blocked in normal mode:

- `/hardware`
- `/setup/hardware`
- `/setup/jobs`
- `/setup/jobs/...`
- other `/setup/...` paths

## Backups

Backend backup:

`/usr/local/bin/prism-setup-backend.backup-20260515-public-state-sanitizer`

Nginx backup:

`/etc/nginx/sites-available/prism-iris.backup-20260515-public-state-sanitizer`

## Verification

Backend syntax check passed:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
```

Live backend syntax check passed before restart:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend
```

`prism-setup-backend` was restarted and reported active.

Nginx validation passed before reload:

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

The POST verification returned 403 at nginx and did not trigger a backend job.

## Public `/setup/state` Privacy Check

After the fix:

- Raw MAC addresses present: false
- Disk serials present: false
- WWNs present: false
- UUID-like hardware IDs present: false
- `/dev/disk/by-id` paths present: false
- Passwords, tokens, cookies, private keys present: false
- Useful GPU/RAM/disk/NIC status still present: true

## Iris Truth Bridge Check

A bounded chat verification through `/api/chat` using public `/setup/state` passed:

- Iris cited `PRISM_STATE fetched from /setup/state`.
- Iris reported NIC link status, GPU model names, RAM, and disk model/size.
- Iris did not emit raw MAC address patterns.
- Iris did not report disk serial numbers.

The frontend sanitizer remains in place as defense in depth.

## Rollback

Rollback backend:

```bash
cp /usr/local/bin/prism-setup-backend.backup-20260515-public-state-sanitizer \
  /usr/local/bin/prism-setup-backend
chmod 755 /usr/local/bin/prism-setup-backend
python3 -m py_compile /usr/local/bin/prism-setup-backend
systemctl restart prism-setup-backend
systemctl is-active prism-setup-backend
```

Rollback nginx:

```bash
cp /etc/nginx/sites-available/prism-iris.backup-20260515-public-state-sanitizer \
  /etc/nginx/sites-available/prism-iris
nginx -t
systemctl reload nginx
```

## Recommended Next Fix

Add backend gates before exposing any Iris job controls:

- Add per-job `read_only` metadata.
- Block mutating jobs unless an explicit setup-mode marker is active.
- Keep `/setup/jobs` blocked in normal-mode nginx until backend enforcement exists.
- Add `check_prism_status` only after those gates are in place.
