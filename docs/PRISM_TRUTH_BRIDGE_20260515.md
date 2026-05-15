# PRISM Truth Bridge - 2026-05-15

## Summary

Today established a known-good PRISM/Iris truth bridge on the live PRISM target at `192.168.14.115`.

The core result: Iris now receives a grounded `PRISM_STATE` system message derived from `/setup/state`, with privacy-sensitive stable identifiers removed before the state is sent to Ollama. When state is unavailable, Iris receives an explicit unavailable-state message and must refuse to invent hardware or service facts.

## Architecture Boundary

Codex must not install or manage PRISM services directly on `192.168.14.115`.

Iris should install and manage PRISM services through PRISM's verified backend/job system. Codex work on the live target should stay limited to explicit low-risk debugging, checkpointing, UI/config deployment when requested, and documentation. Codex must not bypass Iris/PRISM by manually installing Vaultwarden, AdGuard, SearXNG, Nextcloud, Paperless, Headscale, Jellyfin, or any other PRISM service.

## What Was Broken Before

- Browser `/setup/state` returned `index.html` in normal mode instead of setup/backend JSON.
- The frontend attempted to fetch `/setup/state` but silently continued without grounded hardware state when the fetch failed or returned invalid JSON.
- Iris could hallucinate hardware or imply system access it did not have.
- Previous tests showed Iris inventing GPU details and producing ungrounded claims about logs/configs/commands.
- The raw backend state includes stable identifiers such as disk serials and MAC addresses, which should not be sent into the prompt by default.

## nginx `/setup/state` Bug And Fix

Live normal-mode nginx served `/var/www/prism-chat` and proxied `/api/` to Ollama, but did not proxy `/setup/` to the setup backend.

Before the fix:

```text
http://127.0.0.1:5000/setup/state -> application/json
http://192.168.14.115/setup/state -> text/html index.html
```

Live fix applied to:

```text
/etc/nginx/sites-available/prism-iris
```

The normal-mode PRISM site now proxies:

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

location = /hardware {
    proxy_pass http://127.0.0.1:5000/hardware;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    add_header Cache-Control "no-store";
}
```

After the fix:

```text
http://192.168.14.115/setup/state -> application/json
http://192.168.14.115/hardware -> application/json
```

## Frontend `PRISM_STATE` Injection

Frontend file:

```text
net/ui/index.html
```

The frontend now builds a system message with:

- strict truth rules
- a verified summary derived from `PRISM_STATE`
- the sanitized JSON under `PRISM_STATE:`

The message is injected before the user boot prompt in setup mode and before the normal boot prompt in normal mode when `/setup/state` is available and parses as JSON.

## Serial/MAC Sanitization Before Iris Prompt

Raw backend `/setup/state` remains unchanged for internal/backend use.

Only the copy sent to Iris is sanitized by:

```text
sanitizePrismStateForIris(hardware)
```

The sanitizer recursively redacts stable identifiers including:

- `serial`
- `mac`
- `mac_address`
- `wwn`
- `uuid`
- `by_id`
- `address` when the value looks like a MAC address
- `id` when it looks like a stable hardware identifier
- `path` values containing `/dev/disk/by-id`
- UUID-looking string values

Redaction value:

```text
[REDACTED]
```

The Iris prompt also says redacted values are unavailable and should not be mentioned to the user.

## Missing-State Fallback

If `/setup/state` fails, returns non-OK, returns invalid JSON, or is unavailable in normal mode, the frontend now injects:

```text
PRISM_STATE is unavailable.
You do not currently have verified PRISM hardware or service state available.
Do not invent hardware, services, files, logs, command output, installation results, job results, port numbers, or command output.
If asked about local hardware or installed services, say you do not currently have verified PRISM state available.
Do not suggest commands unless the user asks how to troubleshoot or inspect the system manually.
```

## Test Results

### Grounded Hardware Test

With real `/setup/state`, Iris correctly reported:

- `64139` MB RAM
- 2 NICs with link state
- 1 extra disk, size `2.7T`, model `HGST HDN724030ALE640`
- 2 GPUs:
  - NVIDIA GeForce GTX 980 Ti
  - NVIDIA GeForce GTX 1050 Ti
- recommended model `llama3.1:8b`
- Ollama model installed and GPU ready

Iris stated that CPU/motherboard information was not available when those fields were absent.

### Privacy Test

The sanitized Ollama request body did not contain raw disk serials or raw MAC addresses.

Checks passed:

```text
raw_serials_present_in_payload = False
raw_macs_present_in_payload = False
gpu_names_present = True
ram_present = True
disk_model_size_present = True
nic_link_status_present = True
```

When asked for the disk serial number, Iris answered that it did not have that information in `PRISM_STATE`.

### Missing-State Test

Using a simulated unavailable-state system message through the normal `/api/chat` path, Iris did not invent hardware, services, files, logs, command output, job results, or ports. It said it did not currently have verified PRISM state available.

## Commits And Tags

Known truth-bridge commits:

```text
a5abe0e fix: ground Iris responses in PRISM state
1320e76 fix: sanitize PRISM state before Iris prompt
25406f3 fix: add missing-state Iris fallback
```

Known truth-bridge tags:

```text
truth-bridge-working-20260515
truth-bridge-sanitized-20260515
truth-bridge-missing-state-20260515
```

Latest known-good commit:

```text
25406f3b987848bccd619a1468e190d2331823f1
```

## Checkpoint

Checkpoint directory:

```text
checkpoints/20260515-truth-bridge/
```

It contains:

- live deployed frontend copies
- live nginx PRISM normal-mode config and backup
- sanitized read-only status outputs

## Rollback Commands

Restore the live frontend to the sanitized milestone backup:

```bash
ssh root@192.168.14.115 \
  "cp /var/www/prism-chat/index.html.truth-bridge-sanitized-20260515 /var/www/prism-chat/index.html"
```

Restore the live nginx PRISM normal-mode config to the pre-setup-proxy backup:

```bash
ssh root@192.168.14.115 \
  "cp /etc/nginx/sites-available/prism-iris.backup-20260515-setup-proxy /etc/nginx/sites-available/prism-iris && nginx -t && systemctl reload nginx"
```

Restore repo frontend to the missing-state milestone:

```bash
cd /vault/pve-media/projects/prism
git checkout truth-bridge-missing-state-20260515 -- net/ui/index.html
```

## Recommended Next Phase

The next phase should not be service installation. It should be backend/job integration so Iris can manage services through verified PRISM mechanisms.

Recommended order:

1. Reconcile live `prism-setup-backend` with repo `net/ui/prism-setup-backend.py`; the live backend has job endpoints that the repo copy may not fully match.
2. Define a read-only inventory/status contract for Iris, including source labels and timestamps.
3. Add a backend job result loop so Iris can start an allowed job and receive verified completion/failure output.
4. Add service status reporting through backend endpoints, not model guesses.
5. Only after verified job/status plumbing exists, test core service installs through Iris/backend jobs.

Codex should continue to avoid direct service installs on `115`.

