# PRISM Backup Retention Plan - 2026-05-17

This plan protects PRISM development progress without filling storage with full
disk images, VM images, ISOs, model blobs, or frozen Tiny Iris artifacts.

## Backup Tiers

### A. Git Commits, Tags, And Pushes

Git is the primary backup for source code, docs, scripts, nginx templates, and
deployment history.

Use Git for:

- source code
- repo docs
- scripts
- nginx config templates
- milestone records
- implementation handoff notes
- annotated release/milestone tags

Policy:

- commit often at meaningful boundaries
- push to GitHub after completed work
- keep all Git tags
- use annotated tags for live milestones

### B. Lightweight Live Config Checkpoints

Lightweight checkpoints capture the small live files and verification summaries
needed to recover from bad repo-side deployments without copying giant machine
state.

Checkpoints should be created under:

```text
checkpoints/YYYYMMDD-HHMMSS-lightweight/
```

Each checkpoint should include a manifest, checksums, selected text/config files,
and redacted verification summaries.

### C. Full Image Backups By Explicit Approval Only

Full disk images, VM images, and large artifacts are not routine checkpoints.

Use full image backups only by explicit human approval, normally before and
after major install-flow milestones or image-clean/finalization work.

Do not create full image backups as part of ordinary PRISM feature work.

## Lightweight Checkpoint Contents

Lightweight checkpoints may include:

- current git HEAD
- git status
- relevant tags
- backend file from 115
- frontend file from 115
- nginx PRISM site from 115
- setup-job scripts from 115
- PRISM docs/current state
- service active states
- endpoint verification results
- checksums
- backup manifest

Live files currently in scope:

```text
/usr/local/bin/prism-setup-backend
/var/www/prism-chat/index.html
/etc/nginx/sites-available/prism-iris
/usr/local/lib/prism/setup-jobs/*.sh
/etc/update-motd.d/10-prism
```

The MOTD file is included only if present on the target host.

## What Must Not Go Into Lightweight Checkpoints

Do not include:

- disk images
- VM images
- ISOs
- model blobs
- Tiny Iris artifacts
- raw secrets
- raw MAC addresses
- disk serials
- WWNs
- private keys
- tokens
- cookies
- passwords
- UUID-like hardware IDs
- API keys

Do not copy broad directories such as model stores, image output trees, VM
storage, ISO libraries, or Tiny Iris experiment folders.

## Retention

Suggested retention:

- keep all Git tags
- keep the last 5 lightweight checkpoints
- keep milestone checkpoints referenced by tags
- create full image backups only before/after major install-flow milestones
- never delete automatically until a cleanup job is explicitly approved

This plan intentionally does not prune old backups yet.

## Restore Strategy

Code/docs restore:

- check out the desired GitHub tag or commit
- redeploy reviewed repo files to the dev target

Live config restore:

- use a lightweight checkpoint manifest
- compare checksums
- restore only the specific small file that regressed
- validate syntax before restarting/reloading anything

Full system restore:

- use only an explicitly approved image backup
- treat full-image restore as a major recovery operation, not routine dev

## Safety Notes

MotherShip is the factory/PXE/control box. It must not receive live PRISM files
unless explicitly approved as the target.

`192.168.14.115` is the current live PRISM dev server, not a production
hardcoded address.

Tiny Iris is frozen. Do not checkpoint or copy Tiny Iris artifacts unless a
future task explicitly unfreezes that work.

Before image-clean/finalization, remove dev SSH keys and require a user-chosen
password.

