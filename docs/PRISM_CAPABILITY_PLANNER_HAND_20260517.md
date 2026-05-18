# PRISM Capability Planner Hand - 2026-05-17

Implementation handoff for the read-only Iris capability planner.

## Summary

Added repo support for:

```text
POST /setup/analyze-capabilities
```

The endpoint is deterministic and read-only. It composes existing sanitized and
read-only PRISM setup checks into one capability recommendation object for Iris.
It does not install services, pull models, change GPU settings, restart services,
or expose generic `/setup/jobs`.

## Files Changed

```text
net/ui/prism-setup-backend.py
net/ui/index.html
net/nginx/prism-iris.conf
net/setup-jobs/analyze_capabilities.sh
docs/PRISM_CAPABILITY_PLANNER_HAND_20260517.md
```

## Backend Behavior

The backend accepts optional JSON:

```json
{
  "goals": ["privacy", "local_ai", "files_backups"]
}
```

Accepted goal values:

```text
privacy
passwords
ad_blocking
private_search
files_backups
local_ai
coding_helpers
image_generation
media_music
home_automation
router_firewall_lab
kiosk_factory
not_sure
```

The endpoint returns:

```json
{
  "endpoint": "analyze-capabilities",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "overall": "ready|warning|limited|unknown",
  "summary": "...",
  "hardware_summary": {
    "ram_tier": "...",
    "storage_tier": "...",
    "gpu_tier": "...",
    "network_tier": "...",
    "unknowns": []
  },
  "capability_tiers": {
    "privacy_basics": "recommended|possible|not_recommended|unknown",
    "local_ai": "recommended|possible|not_recommended|unknown",
    "files_backups": "recommended|possible|not_recommended|unknown",
    "kiosk_factory": "recommended|possible|not_recommended|unknown"
  },
  "recommended_roles": [],
  "recommended_services": [],
  "possible_services": [],
  "not_recommended_services": [],
  "blockers": [],
  "questions_for_user": [],
  "hardware_upgrade_suggestions": [],
  "next_safe_action": "...",
  "confidence": "high|medium|low"
}
```

The implementation reuses:

- sanitized setup state
- read-only PRISM status check
- install readiness check
- blocker diagnosis when readiness is warning/blocked/limited/failed/unknown
- AI runner readiness check

## Iris UI Behavior

The browser calls `POST /setup/analyze-capabilities` when the user asks
capability-planning questions such as:

- "What can this PRISM box do?"
- "What should I install?"
- "What is this hardware good for?"
- "Help me choose what to set up"
- "What can PRISM do with this computer?"
- "I'm not sure what I want"

The result is injected into Iris as `PRISM_BACKEND_RESULT` with instructions to:

- say "Here is what the PRISM backend reported:"
- report only what the backend returned
- not claim anything was installed
- not claim services changed
- not claim commands were run personally
- not invent hardware, services, files, logs, ports, job results, or command
  output
- distinguish Iris/operator behavior from helper/runner models
- mention image generation only as an optional possible GPU use
- ask what goals matter most before recommending system-changing actions

## Public Route

`net/nginx/prism-iris.conf` now includes an exact allowlisted route:

```text
/setup/analyze-capabilities
```

Generic setup jobs remain blocked:

```text
location ^~ /setup/jobs {
    return 403;
}
```

## Safety

The endpoint must always return:

```json
{
  "read_only": true,
  "changed_files": [],
  "changed_services": []
}
```

It does not expose `/setup/jobs`, and it does not add any mutating job path.

## Local Verification

Passed:

```text
python3 -m py_compile net/ui/prism-setup-backend.py
bash -n net/setup-jobs/analyze_capabilities.sh
git diff --check
```

Local import/smoke test returned:

```json
{
  "endpoint": "analyze-capabilities",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "has_summary": true,
  "capability_keys": [
    "files_backups",
    "kiosk_factory",
    "local_ai",
    "privacy_basics"
  ]
}
```

Local privacy check on planner output:

```text
raw MAC addresses present: false
disk serial values present: false
WWN values present: false
UUID-like hardware ID values present: false
/dev/disk/by-id paths present: false
password/token/cookie/private key values present: false
useful capability planning info present: true
```

Note: service labels may contain words such as "Password manager"; that is not a
secret value.

## Live Deployment Status

Live deployment to `192.168.14.115` completed from MotherShip after dev SSH
access was restored.

Deployed files:

```text
/usr/local/bin/prism-setup-backend
/usr/local/lib/prism/setup-jobs/analyze_capabilities.sh
/var/www/prism-chat/index.html
/etc/nginx/sites-available/prism-iris
```

Live backup paths:

```text
/usr/local/bin/prism-setup-backend.backup-20260517-capability-planner
/var/www/prism-chat/index.html.backup-20260517-capability-planner
/etc/nginx/sites-available/prism-iris.backup-20260517-capability-planner
```

Live validation passed:

```text
python3 -m py_compile /usr/local/bin/prism-setup-backend
bash -n /usr/local/lib/prism/setup-jobs/analyze_capabilities.sh
nginx -t
systemctl is-active prism-setup-backend: active
```

Services restarted/reloaded:

```text
systemctl restart prism-setup-backend
systemctl reload nginx
```

No services were installed. No packages were installed. No models were changed.
No GPU settings were changed. No mutating jobs were triggered.

Public checks from MotherShip:

```text
POST /setup/analyze-capabilities: 200 OK
POST /setup/analyze-capabilities {"goals":["privacy","local_ai"]}: 200 OK
GET /setup/jobs: 403 Forbidden
POST /setup/jobs/install_vaultwarden: 403 Forbidden
GET /setup/state: 200 OK, sanitized JSON
GET /hardware: 403 Forbidden
GET /setup/hardware: 403 Forbidden
```

Capability planner response summary:

```text
read_only: true
changed_files: []
changed_services: []
overall: warning
hardware_summary.ram_tier: very_high
hardware_summary.storage_tier: storage_heavy
hardware_summary.gpu_tier: multi_gpu_ready
hardware_summary.network_tier: multi_nic
next_safe_action: Explain the blockers and ask which goal to plan around first. Do not start installs.
```

Live privacy check on planner output:

```text
raw MAC addresses present: false
disk serial values present: false
WWN values present: false
UUID-like hardware ID values present: false
/dev/disk/by-id paths present: false
password/token/cookie/private key values present: false
useful capability planning info present: true
```

Iris behavior test with:

```text
What can this PRISM box do?
```

Result:

```text
Iris began with "Here is what the PRISM backend reported:"
Iris described RAM, extra storage, GPUs, and good-fit roles from backend data.
Iris asked the user to choose goals before install planning.
Iris did not claim anything was installed.
Iris did not claim services were changed.
Iris mentioned image generation only as an optional GPU use.
```

Representative Iris response excerpt:

```text
Here is what the PRISM backend reported:

This machine reports 62.6GB RAM, about 2.7TB extra storage, 2 GPU devices reported.
It is a good candidate for PRISM dev/local AI/helper runner work, with image
generation only as an optional GPU use.
```

## Required Live Deployment Steps

Completed on 115:

1. Backed up live files:

   ```text
   /usr/local/bin/prism-setup-backend.backup-20260517-capability-planner
   /var/www/prism-chat/index.html.backup-20260517-capability-planner
   /etc/nginx/sites-available/prism-iris.backup-20260517-capability-planner
   ```

2. Copied updated files:

   ```text
   net/ui/prism-setup-backend.py -> /usr/local/bin/prism-setup-backend
   net/ui/index.html -> /var/www/prism-chat/index.html
   net/nginx/prism-iris.conf -> /etc/nginx/sites-available/prism-iris
   net/setup-jobs/analyze_capabilities.sh -> /usr/local/lib/prism/setup-jobs/analyze_capabilities.sh
   ```

3. Verified syntax on 115:

   ```text
   python3 -m py_compile /usr/local/bin/prism-setup-backend
   bash -n /usr/local/lib/prism/setup-jobs/analyze_capabilities.sh
   nginx -t
   ```

4. Restarted/reloaded only changed services:

   ```text
   systemctl restart prism-setup-backend
   systemctl reload nginx
   ```

5. Verified public behavior:

   ```text
   POST /setup/analyze-capabilities: 200 OK
   POST /setup/analyze-capabilities {"goals":["privacy","local_ai"]}: 200 OK
   GET /setup/jobs: 403 Forbidden
   POST /setup/jobs/install_vaultwarden: 403 Forbidden
   GET /setup/state: 200 OK, sanitized JSON
   GET /hardware: 403 Forbidden
   GET /setup/hardware: 403 Forbidden
   ```

6. Tested Iris with:

   ```text
   What can this PRISM box do?
   ```

   Response began with:

   ```text
   Here is what the PRISM backend reported:
   ```

   Iris should explain hardware fit, ask about goals, and not claim any install
   or service change.
