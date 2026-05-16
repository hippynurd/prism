# PRISM Image Clean State Plan - 2026-05-16

## Goal

Add an explicit PRISM lifecycle for preparing a development box to become a safe
image source.

This document is design-only. It does not authorize cleanup, credential changes,
model deletion, service restarts, package installation, or mutating backend jobs.

## Lifecycle States

### bootstrap

Initial install/provisioning state.

Expected properties:

- Bootstrap/default credentials may still exist.
- Setup mode may be enabled.
- Installer files, setup logs, and generated artifacts may exist.
- Public setup routes may be temporarily available only as required by the
  installer flow.
- The box is not safe to image.

Exit criteria:

- Core PRISM services are installed and reachable.
- Setup state is known.
- User has a path to replace default/bootstrap credentials.

### dev

Normal active development state.

Expected properties:

- Repo and live services may change through normal development.
- Test artifacts, checkpoint archives, docs, logs, temporary Codex/Claude files,
  and experimental models may exist.
- `/setup/state` must stay sanitized.
- `/hardware`, `/setup/hardware`, and `/setup/jobs` must stay blocked publicly.
- The box is not assumed safe to image.

Exit criteria:

- User requests an image-readiness audit.
- `check_image_cleanliness` reports what blocks image readiness.

### image-clean

Prepared image-source state.

Expected properties:

- Default/bootstrap credentials are replaced.
- Setup mode is disabled or clearly marked complete.
- Public setup/job/hardware exposure is blocked.
- Public setup state remains sanitized.
- Experimental model artifacts, temp files, caches, shell histories, and
  downloaded installers are either removed or explicitly accepted.
- Cleanup report exists.
- Remaining known risks are documented.

Exit criteria:

- User reviews cleanup report and explicitly accepts the host as an image
  source.
- Credential finalization has verified a valid login path.

### finalized

Frozen image-source state.

Expected properties:

- Credentials are finalized.
- Image-clean report is present.
- No pending cleanup actions are required.
- No default/bootstrap credential path remains active.
- The user has confirmed the image should be captured from this state.

Exit criteria:

- Image capture is complete.
- Any later development moves the system back to `dev`.

## Read-Only Job Design: check_image_cleanliness

`check_image_cleanliness` should be the first implementation. It is read-only
and must not remove files, change credentials, restart services, mutate models,
or trigger install/cleanup jobs.

### Inputs

- Optional repo root path, defaulting to the known PRISM repo path.
- Optional age window for recent artifact checks.
- Optional allowlist for accepted models or known generated files.

### Outputs

The job should return JSON with:

- `status`: `clean`, `needs_cleanup`, `blocked`, or `error`.
- `read_only`: always `true`.
- `lifecycle_state_guess`: one of `bootstrap`, `dev`, `image-clean`,
  `finalized`, or `unknown`.
- `findings`: categorized list of checks and evidence.
- `risks`: normalized risk items with severity.
- `recommended_cleanup_plan`: commands or actions for later review, not run.
- `redactions`: count and type of redactions applied.
- `summary`: short human-readable result for Iris.

### Checks

Credential and setup state:

- Default/bootstrap credentials still active.
- Setup-mode markers present.
- Setup completion markers present.
- Credential finalization marker present.

Model and training artifacts:

- Experimental Ollama models outside the approved model list.
- Tiny model bakeoff artifacts.
- `Modelfile` files.
- Training datasets and `*.jsonl` files.
- Files or paths matching `IrisCore`, `IrisCode`, `iris-core`, `iris-code`,
  `qwen`, `llama3.2`, `tiny-iris`, `fine-tune`, `training`, and
  `test-iris-models`.

AI-agent and temp files:

- Codex temp files.
- Claude temp files.
- Aider temp files.
- Shell histories that may contain commands or sensitive material.
- SSH key and `known_hosts` concerns.

Package and installer residue:

- apt package caches.
- downloaded installers.
- temporary package archives.
- recent apt history entries.

Repo and checkpoint hygiene:

- Untracked repo files.
- Checkpoint archives.
- Build outputs that should not be baked into an image.
- Generated reports that contain host-specific data.

Privacy and public API safety:

- Logs/docs containing raw MAC addresses.
- Logs/docs containing disk serials.
- Public `/setup/jobs` exposure.
- Raw `/hardware` exposure.
- Public `/setup/state` sanitization.

### Redaction Rules

The job must not emit:

- passwords
- tokens
- cookies
- private keys
- API keys
- raw MAC addresses
- disk serials

When a sensitive value is found, the job should report the category, path, and
line number or field path where possible, with the value redacted.

## Mutating Cleanup Job Design: prepare_image_clean_state

`prepare_image_clean_state` should not be implemented until
`check_image_cleanliness` is stable and trusted.

Rules:

- Requires explicit user confirmation.
- Must show the planned actions before execution.
- Must support dry-run mode.
- Must not silently change passwords.
- Must not delete Ollama models unless each model is specifically approved.
- Must not delete repo files unless they are clearly generated or temporary.
- Must preserve evidence in a cleanup report.
- Must provide rollback notes where rollback is possible.
- Must report actions actually taken, skipped, failed, and requiring manual
  review.

Expected cleanup categories:

- Remove approved temp files.
- Remove approved checkpoint archives from the image source.
- Clear approved shell histories only after user confirmation.
- Remove approved downloaded installers and package caches.
- Remove approved tiny-model bakeoff artifacts.
- Remove approved experimental Ollama models.
- Confirm public endpoint safety after cleanup.

Non-goals:

- No destructive cleanup without confirmation.
- No credential finalization.
- No service restarts unless separately approved.
- No package installation.

## Credential Finalization Design: finalize_credentials

`finalize_credentials` should be a separate explicit lifecycle step.

Rules:

- User chooses the password.
- PRISM must not generate a random password without explicit approval.
- Setup is not finalized until default/bootstrap credentials are replaced.
- Avoid lockout by verifying a valid login path before declaring success.
- Do not write plaintext passwords to logs, reports, shell history, process
  arguments, or git.
- Store only the minimum required state marker that credentials were finalized.

Safe flow:

1. Explain the current credential state and risk.
2. Ask the user to choose the new credential through a safe input path.
3. Apply the credential change only after explicit confirmation.
4. Verify login or an equivalent non-lockout path.
5. Mark credential finalization complete only after verification succeeds.
6. Record a report that omits secrets.

Failure handling:

- If verification fails, do not mark finalized.
- Keep rollback or recovery instructions visible to the user.
- Do not continue to image-clean/finalized automatically.

## Iris Behavior

Iris should be a reporter and consent layer, not a source of truth.

Required behavior:

- Iris explains the current lifecycle state.
- Iris reports backend findings only.
- Iris asks before cleanup.
- Iris asks before credential finalization.
- Iris does not claim cleanup happened unless the backend result says cleanup
  happened.
- Iris does not claim credentials changed unless the backend result says
  credential finalization succeeded.
- Iris clearly distinguishes read-only audit findings from mutating cleanup
  results.
- Iris must surface redaction counts and manual-review blockers.

Example language:

- "PRISM appears to be in dev state. The backend found image-readiness blockers."
- "I can prepare a cleanup plan, but I will not remove models or files without
  your approval."
- "Cleanup has not run yet."

## Recommended First Implementation

Implement `check_image_cleanliness` first.

Do not implement cleanup yet.

Do not implement credential finalization yet.

Initial patch should include:

- A read-only backend job named `check_image_cleanliness`.
- Public API route design consistent with the existing read-only status job.
- Strict redaction of sensitive values.
- Tests for public endpoint safety checks.
- Tests that the job does not mutate files, services, models, or credentials.
- Documentation describing how to interpret `clean`, `needs_cleanup`,
  `blocked`, and `error`.

Recommended initial status mapping:

- `clean`: no blockers found, no cleanup required.
- `needs_cleanup`: removable artifacts or non-fatal hygiene issues found.
- `blocked`: credentials, public exposure, raw hardware exposure, or sensitive
  data leaks prevent imaging.
- `error`: the job could not complete enough checks to make a recommendation.

The first patch should not add any job capable of deletion, service changes,
model changes, credential changes, or package changes.
