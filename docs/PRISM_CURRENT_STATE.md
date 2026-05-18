# PRISM Current State

Snapshot date: 2026-05-18.

Latest known pushed HEAD before this restart packet:

```text
8044313 docs: record MotherShip MOTD cleanup
```

## Current Pushed Tags

```text
working-browser-20260515
truth-bridge-working-20260515
truth-bridge-sanitized-20260515
truth-bridge-missing-state-20260515
secure-truth-bridge-20260515
backend-hands-v1-internal-20260515
backend-hands-v1-public-status-20260515
iris-status-loop-v1-20260515
iris-blocker-diagnosis-v1-20260516
iris-ai-runner-readiness-v1-20260516
```

Known good tags called out for restart context:

```text
secure-truth-bridge-20260515
backend-hands-v1-internal-20260515
backend-hands-v1-public-status-20260515
iris-status-loop-v1-20260515
iris-blocker-diagnosis-v1-20260516
iris-ai-runner-readiness-v1-20260516
```

## Machine Roles

MotherShip:

- IP: `192.168.14.1`
- Role: factory, PXE, and control box
- Must not receive live PRISM files unless explicitly approved as the target
- The PRISM MOTD contamination was audited and cleaned

115:

- IP: `192.168.14.115`
- Role: current live PRISM dev server
- This is a dev address, not a production hardcoded IP

FM09/9:

- Role: borrowed work hardware used for Tiny Iris model experiments
- Temporary helper/model/build node, not a required PRISM dependency
- Tiny Iris work is frozen and preserved for now

## What Works

Regular Iris and PRISM eyes/hands are the current focus on the 115 dev server.

Known live PRISM endpoints on 115:

```text
/setup/state
/setup/check-prism-status
/setup/check-install-readiness
/setup/diagnose-install-blockers
/setup/check-ai-runner-readiness
```

Endpoint intent:

- `/setup/state` is sanitized.
- `/setup/check-prism-status` is read-only.
- `/setup/check-install-readiness` is read-only.
- `/setup/diagnose-install-blockers` is read-only.
- `/setup/check-ai-runner-readiness` is read-only.

MotherShip MOTD cleanup:

- audit committed
- wrong active PRISM MOTD moved out of `/etc/update-motd.d`
- cleanup note committed
- latest known pushed cleanup commit: `8044313`

## Blocked For Safety

These public endpoints are blocked and must stay blocked unless explicitly
redesigned and secured:

```text
/hardware
/setup/hardware
/setup/jobs
/setup/jobs/*
```

Do not expose generic `/setup/jobs` publicly.

Do not print or commit secrets, raw MACs, disk serials, tokens, passwords,
cookies, private keys, UUID-like hardware IDs, or API keys.

## Frozen

Tiny Iris work is frozen and preserved for now.

Do not touch FM09/9 artifacts unless explicitly asked.

Do not clean image artifacts during active development.

## Not Done

PRISM does not yet have a final gated installer flow.

Iris should become the installer/operator, but real install jobs should not be
started yet.

Production IP and final host assumptions are not settled. Browser code should
use relative paths; internal service calls should use localhost or explicit
configuration.

Image-clean/finalization is later. Before that phase, remove dev SSH keys and
require a user-chosen password.

## Immediate Next Recommended Work

1. Build a capability planner / setup recommender for Iris.
2. Polish browser wording for regular Iris.
3. Later, design gated install jobs.
4. Do not start real installs yet.

