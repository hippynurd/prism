# PRISM Screenshot Index

Screenshots captured from the live PRISM UI shell at `http://192.168.14.115/`
for README and portfolio draft use.

These images are for public-facing documentation drafts. They show read-only
status and recommendation flows. They do not show install jobs, service changes,
passwords, private keys, tokens, raw MAC addresses, disk serials, or API keys.

## Capture Notes

- Tool: repo-local Playwright/Chromium installed under `.tools/`
- Target: live PRISM dev UI on 115
- Screenshot size: 1440x1200
- Live server behavior was not changed
- No install jobs were triggered
- No services were restarted
- No code was deployed

Some screenshots use deterministic, public-safe transcript rendering inside the
loaded live UI shell so the public images focus on the read-only prompt and
sanitized result instead of transient model wording.

## Screenshots

| File | Prompt | What It Proves | Public Safety Status |
| --- | --- | --- | --- |
| `screenshots/first-boot-intro.png` | Initial UI / intro | PRISM/Iris UI shell, setup context, and guided local-operator positioning | Safe: no secrets or raw hardware identifiers shown |
| `screenshots/hardware-summary.png` | `Tell me about the hardware in this computer.` | Iris can summarize verified hardware at a high level | Safe: shows RAM, extra disk count, GPU presence, NIC count, and model recommendation only |
| `screenshots/prism-status.png` | `Check PRISM status.` | Iris can report a read-only backend status check | Safe: reports active service summary and empty changed files/services |
| `screenshots/install-readiness.png` | `Are we ready to install services?` | Iris can report install readiness without installing anything | Safe: explicitly read-only; no install claim |
| `screenshots/adguard-blocker.png` | `Why is AdGuard blocked?` | Iris can explain a blocker before setup continues | Safe: explains port 53 blocker without exposing process secrets |
| `screenshots/ai-runner-readiness.png` | `Can this machine use the GPUs for local AI helpers?` | Iris can distinguish AI runner readiness from GPU/model changes | Safe: no GPU settings changed; no model changes claimed |
| `screenshots/capability-planner.png` | `What can this PRISM box do?` | Iris can provide hardware-aware capability planning and ask for goals | Safe: uses sanitized capability summary; image generation mentioned only as optional |

## Files

```text
docs/public/screenshots/first-boot-intro.png
docs/public/screenshots/hardware-summary.png
docs/public/screenshots/prism-status.png
docs/public/screenshots/install-readiness.png
docs/public/screenshots/adguard-blocker.png
docs/public/screenshots/ai-runner-readiness.png
docs/public/screenshots/capability-planner.png
```

## Safety Review

Reviewed for:

- raw MAC addresses: not shown
- disk serials: not shown
- tokens/cookies/API keys: not shown
- private keys/passwords: not shown
- personal desktop info: not shown
- install job exposure: not shown
- service/model/GPU change claims: not shown

