# PRISM AI Runner Readiness Hand

Date: 2026-05-16

## What was added

PRISM now exposes a read-only public-safe backend hand:

`POST /setup/check-ai-runner-readiness`

It reports whether the machine looks suitable for local AI helpers, LLMs, coding agents, backend runners, and optional GPU-assisted workloads.

## Why this is not an install/config job

This hand does not:

- install packages
- pull models
- delete models
- change GPU drivers
- change GPU assignment
- change Ollama models
- restart AI services
- expose generic `/setup/jobs`

It only reports backend findings.

## Endpoint behavior

The endpoint returns sanitized JSON with:

- `read_only: true`
- `changed_files: []`
- `changed_services: []`
- GPU visibility and candidate role hints
- Ollama state and installed model names
- RAM and disk suitability
- whether public safety checks still pass
- whether Iris and agent GPU assignment is verified
- safe next steps only

It also keeps `/setup/jobs` blocked publicly and does not expose mutating install jobs.

## Iris behavior

Iris uses the backend result as the only source of truth.

When the user asks about local AI runner readiness, Iris should say:

`Here is what the PRISM backend reported:`

Then it should summarize the backend result only. If assignments are unknown, Iris must say they are unknown. If the backend check fails, Iris must say the check failed or was unavailable.

## Live 115 result

On `192.168.14.115`, the endpoint is deployed and working.

Current reported state:

- `overall: warning`
- two NVIDIA GPUs visible
- Ollama active
- installed models include `llama3.1:8b` and `qwen2.5:1.5b`
- GPU assignment is not verified
- `iris_gpu` and `agent_gpu` remain unknown
- public safety checks still pass
- `changed_files` and `changed_services` are empty

Suggested roles reported by the backend:

- local Iris assistant
- helper LLM
- coding/log/script runner
- backend runner
- optional image generation workload

## Privacy results

Readiness output was checked for leakage.

- raw MAC addresses present? false
- disk serial values present? false
- WWN values present? false
- UUID-like hardware ID values present? false
- `/dev/disk/by-id` paths present? false
- password/token/cookie/private key values present? false
- useful AI/GPU readiness info present? true

## Safety boundaries

Public safety surfaces still block:

- `/setup/jobs`
- `/setup/jobs/*`
- `/hardware`
- `/setup/hardware`

No model, service, or GPU setting was changed.

## Why this helps older PCs

This hand lets PRISM explain, without changing anything, whether older office PCs or older gaming PCs can serve as:

- a local Iris/operator host
- a lightweight helper LLM box
- a coding or log-analysis runner
- a backend runner

That is the right first step before any actual helper or runner setup.

## Next step

The next step is to keep this as a diagnostic hand and only add any GPU or agent assignment changes after explicit user confirmation.
