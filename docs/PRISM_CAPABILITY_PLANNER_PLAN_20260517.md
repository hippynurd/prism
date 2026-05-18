# PRISM Capability Planner Plan - 2026-05-17

Design-only plan for `POST /setup/analyze-capabilities`.

This endpoint lets Iris explain what PRISM can do on the current machine and
recommend next setup steps from sanitized hardware state, readiness checks,
blockers, AI-runner readiness, and optional user goals.

The endpoint is read-only. It must not install anything, start jobs, expose
`/setup/jobs`, change services, change models, alter nginx/systemd, or make
assumptions from unverified hardware.

## Design Overview

The capability planner should be the bridge between raw setup diagnostics and
Iris as an operator assistant.

It should answer:

- what can this machine do?
- what is this hardware good for?
- what should I install first?
- what can PRISM help me set up?
- what hardware would I need to add for my goals?

The endpoint should combine existing read-only setup signals into a single
recommendation object. Iris can then present the result conversationally without
claiming that anything was installed or that Iris personally ran commands.

This planner is not the install system. It is a recommendation layer that helps
the user choose goals and understand constraints before any future gated install
job exists.

## Endpoint Design

```text
POST /setup/analyze-capabilities
```

Request body:

```json
{
  "goals": [
    "privacy",
    "passwords",
    "ad_blocking",
    "private_search",
    "files_backups",
    "local_ai",
    "coding_helper_agents",
    "image_generation",
    "media_music",
    "home_automation",
    "router_firewall_lab",
    "kiosk_factory_workflows",
    "not_sure"
  ]
}
```

The body is optional. If no goals are provided, the backend should return a
general recommendation and questions for the user.

Goal IDs should be normalized internally. Browser copy may use friendlier labels:

```text
privacy
passwords
ad blocking
private search
files/backups
local AI
coding/helper agents
image generation
media/music
home automation
router/firewall/lab
kiosk/factory workflows
I'm not sure
```

The endpoint should call or reuse the same read-only logic behind:

```text
/setup/state
/setup/check-prism-status
/setup/check-install-readiness
/setup/diagnose-install-blockers
/setup/check-ai-runner-readiness
```

`diagnose-install-blockers` can be included when readiness is blocked or partial.
It can also be included unconditionally if it remains read-only and cheap, but
the response should distinguish hard blockers from cautionary warnings.

The endpoint must return a stable JSON shape even when some sources are missing.
Missing sources should be represented as unknowns, not invented facts.

## Input Sources

Primary inputs:

- sanitized `PRISM_STATE`
- `check-prism-status` result
- `check-install-readiness` result
- `diagnose-install-blockers` result when relevant
- `check-ai-runner-readiness` result
- optional user goals

The endpoint must not read public-blocked raw hardware endpoints:

```text
/hardware
/setup/hardware
/setup/jobs
/setup/jobs/*
```

The endpoint must not expose raw identifiers in its own response. It should not
return secrets, raw MACs, disk serials, tokens, passwords, cookies, private keys,
UUID-like hardware IDs, or API keys.

## Output JSON Shape

Recommended top-level response:

```json
{
  "endpoint": "/setup/analyze-capabilities",
  "read_only": true,
  "changed_files": [],
  "changed_services": [],
  "hardware_summary": {
    "machine_class": "multi_gpu_machine",
    "cpu": {
      "summary": "CPU details if safely available",
      "confidence": "medium"
    },
    "memory": {
      "summary": "RAM details if safely available",
      "confidence": "high"
    },
    "storage": {
      "summary": "Storage capacity/role summary if safely available",
      "confidence": "medium"
    },
    "gpu": {
      "summary": "GPU capability summary if safely available",
      "verified": true,
      "confidence": "high"
    },
    "network": {
      "wifi_detected": null,
      "bluetooth_detected": null,
      "confidence": "low"
    },
    "notes": []
  },
  "capability_tiers": [
    {
      "tier": "strong_fit",
      "label": "Strong fit",
      "capabilities": []
    },
    {
      "tier": "possible",
      "label": "Possible",
      "capabilities": []
    },
    {
      "tier": "not_recommended",
      "label": "Not recommended right now",
      "capabilities": []
    }
  ],
  "recommended_roles": [],
  "recommended_services": [],
  "possible_services": [],
  "not_recommended_services": [],
  "blockers": [],
  "questions_for_user": [],
  "hardware_upgrade_suggestions": [],
  "next_safe_action": {
    "type": "ask_user_goal",
    "label": "Ask what the user wants PRISM to help with first",
    "read_only": true
  },
  "confidence": "medium",
  "unknowns": []
}
```

Suggested machine classes:

```text
old_office_pc_no_gpu
office_pc_decent_ram_storage
old_gaming_pc_with_gpu
multi_gpu_machine
storage_heavy_machine
weak_machine_tiny_iris_later
unknown
```

Suggested service recommendation object:

```json
{
  "id": "adguard_home",
  "label": "Ad blocking DNS",
  "fit": "strong_fit",
  "why": "Good first privacy service if networking prerequisites are ready.",
  "requires": ["stable network", "DNS/router choice"],
  "blocked_by": [],
  "risk": "low",
  "installable_now": false,
  "read_only_recommendation": true
}
```

`installable_now` should mean "the planner sees no obvious blocker", not "the
backend will install this now." Until gated install jobs are designed, Iris must
still explain that this is a recommendation only.

## Hardware-Aware Capability Mapping

The planner should map sanitized hardware into capability tiers.

Old office PC, no GPU:

- strong fit: ad blocking, private search, password manager, lightweight files,
  backups, home dashboard, light home automation
- possible: small local helper model only if AI readiness says available
- not recommended: image generation, large local LLMs, heavy media transcoding

Office PC with decent RAM/storage:

- strong fit: privacy basics, files/backups, private search, password manager,
  home automation, media library without heavy transcoding
- possible: small to medium local AI, coding helper if CPU/RAM is enough
- not recommended: heavy image generation or large model serving without GPU

Old gaming PC with GPU:

- strong fit: local AI helper models, coding/helper agents, media workflows,
  privacy basics
- possible: image generation if GPU readiness and VRAM are verified
- not recommended: always-on router/firewall if power use or NIC layout is poor

Multi-GPU machine like 115:

- strong fit: local AI runner, helper/runner models, coding agents, image
  generation as one possible GPU use, heavier media or batch jobs
- possible: privacy basics, files/backups, home automation
- not recommended: production router/firewall unless network interfaces and
  operational constraints are explicitly verified

Wi-Fi/Bluetooth presence if detectable:

- mention only if verified by sanitized state or readiness output
- if unknown, ask whether wireless/Bluetooth devices matter
- do not invent assignments or device names

Storage-heavy machine:

- strong fit: files, backups, media/music, local archives
- possible: local AI if CPU/GPU readiness supports it
- not recommended: GPU-heavy workflows if no GPU is verified

Weak machine that should use Tiny Iris later:

- strong fit: simple privacy basics, light status UI, small operator shell
- possible: Tiny Iris later when frozen work resumes
- not recommended: current regular Iris heavy AI serving, image generation,
  large helper models

## Iris Behavior

Iris should start with:

```text
Here is what the PRISM backend reported:
```

Then Iris should:

- explain what hardware was found
- explain what this machine is good for
- ask the user about goals
- mention image generation only as one possible GPU use, not an assumed goal
- distinguish the Iris/operator model from helper/runner models
- avoid inventing Wi-Fi, Bluetooth, GPU, model, disk, or service assignments
- avoid claiming anything was installed
- avoid claiming commands were run personally
- recommend, but not act

Suggested explanation pattern:

```text
Here is what the PRISM backend reported:

This machine looks like a strong fit for local AI runner work because PRISM can
see verified GPU capacity. Iris is the operator model: it explains status and
guides setup. Helper or runner models are separate models that can do coding,
summarization, image work, or other heavier tasks.

For a first PRISM setup, I would start with privacy basics and a read-only
capability check. I would not start real installs yet.

What do you want this box to help with first: privacy, files/backups, local AI,
coding helpers, media/music, home automation, router/lab work, or are you not
sure yet?
```

If hardware is weak:

```text
Here is what the PRISM backend reported:

This machine looks better suited for lightweight PRISM services than heavy local
AI. It can still be useful for privacy basics, simple status checks, and small
home services. Tiny Iris may be a later fit, but that work is frozen right now.

I would avoid image generation and large helper models on this hardware unless a
GPU or another runner machine is added.
```

If storage is strong:

```text
Here is what the PRISM backend reported:

This machine looks useful as a storage-heavy PRISM box. Files, backups, media,
and local archives are better fits than GPU-heavy AI work unless the backend also
reports verified GPU readiness.
```

If readiness is blocked:

```text
Here is what the PRISM backend reported:

PRISM found blockers before setup should continue. I can explain the blockers
and recommend a safe next step, but I should not start an install.
```

## Example Conversations

User:

```text
What can this PRISM box do?
```

Iris:

```text
Here is what the PRISM backend reported:

This machine appears to be a strong fit for PRISM privacy basics and local
assistant workflows. The backend reports that status and readiness checks are
available, and AI-runner readiness can be evaluated separately from Iris itself.

Iris is the operator assistant. Helper or runner models are separate tools that
can support coding, summarization, media tasks, or image generation if the
hardware supports them.

I would start with privacy basics, then choose whether this box should focus on
files/backups, local AI, coding helpers, media/music, home automation, or
router/lab work. I would not start real installs yet.

What do you want PRISM to help with first?
```

User:

```text
Can it do image generation?
```

Iris:

```text
Here is what the PRISM backend reported:

Image generation is one possible GPU use, but I need verified GPU and VRAM
readiness before recommending it. If PRISM reports a capable GPU, image
generation can be listed as possible or strong-fit. If no GPU is verified, I
would treat it as not recommended on this machine.
```

User:

```text
I just want privacy stuff.
```

Iris:

```text
Here is what the PRISM backend reported:

For a privacy-first setup, I would recommend starting with the least risky
building blocks: DNS/ad blocking, private search, password management, and
backups. If readiness checks show blockers, I would resolve those first.

This is a recommendation only. I will not start install jobs from this screen.
```

## Safety Rules

The endpoint must always report:

```json
{
  "read_only": true,
  "changed_files": [],
  "changed_services": []
}
```

The endpoint must not:

- install packages
- start, stop, restart, enable, or disable services
- expose `/setup/jobs`
- trigger backend jobs
- change nginx, backend, frontend, Ollama, models, GPU settings, passwords, SSH,
  or systemd
- touch MotherShip unless explicitly targeted
- touch FM09/9 or Tiny Iris artifacts
- return secrets or raw hardware identifiers
- claim a service is installed unless existing sanitized status confirms it
- claim Wi-Fi, Bluetooth, GPU, or disk assignments unless verified

The browser should treat this as advice. Any future install action must be a
separate gated flow with explicit user confirmation.

## Relationship To Future Install Flow

The capability planner should become the decision layer before install jobs.

Future sequence:

1. Read sanitized state and readiness.
2. Analyze capabilities.
3. Ask user goals.
4. Recommend a plan.
5. Explain blockers.
6. Ask for explicit confirmation.
7. Only later, call a gated install-job endpoint.

This design intentionally keeps step 7 out of scope.

Future install jobs should not reuse generic public `/setup/jobs`. They should
use narrow, named, gated actions with explicit target checks, auth/approval, dry
run support, clear rollback notes where possible, and no raw secret/hardware ID
leakage.

## Recommended First Implementation Patch

First patch should be backend-only plus minimal browser wiring, still read-only.

Recommended scope:

1. Add a backend helper that normalizes existing read-only check outputs into a
   planner input object.
2. Add `POST /setup/analyze-capabilities`.
3. Implement deterministic rule-based classification first, without LLM calls.
4. Return the stable JSON shape above.
5. Add browser UI that calls the endpoint and renders Iris wording as
   recommendation text.
6. Add tests or a local fixture path for at least:
   - weak/no-GPU office PC
   - decent office PC with storage
   - GPU machine
   - multi-GPU machine
   - blocked readiness
   - unknown hardware

Do not start real installs in this patch.

Do not add `/setup/jobs` exposure.

Do not hardcode `192.168.14.115` as production behavior. Browser calls should
use relative paths.

## Biggest Open Questions

- What exact sanitized fields does `/setup/state` currently provide for CPU,
  RAM, storage, GPU, network, Wi-Fi, Bluetooth, and service status?
- Should `diagnose-install-blockers` run every time, or only when readiness is
  blocked or partial?
- Which service IDs and labels should be the canonical PRISM catalog names?
- Should the planner include a `dry_run_install_plan` object now, or wait until
  gated install-job design?
- How should confidence be scored: fixed labels, numeric score, or both?
- Which recommendations should be shown to all users, and which should only
  appear after the user selects goals?
- What wording should Iris use when a machine is too weak for regular local AI
  while Tiny Iris remains frozen?

