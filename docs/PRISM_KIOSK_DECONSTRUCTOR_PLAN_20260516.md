# PRISM Kiosk Deconstructor Plan

Date: 2026-05-16

## Purpose

PRISM should treat kiosk deconstruction as a profile-extraction workflow, not an image-editing workflow.

The goal is to inspect an existing kiosk system, understand what makes it special, and turn that into a clean rebuild profile that can later be used to build the next kiosk from stock OS plus documented changes.

## North-Star Workflow

1. Deconstruct the old kiosk image.
2. Understand what makes it special.
3. Compare it against a stock baseline.
4. Preserve what works.
5. Flag fragile, accidental, or private cruft.
6. Generate a clean rebuild profile.
7. Later build the next-gen kiosk from stock OS plus the profile.

## First Implementation

The first implementation should be:

`analyze_kiosk_image_metadata`

This must be read-only only.

It should detect:

- image type
- OS version
- partitions
- read-only mountability
- package manager
- likely kiosk markers

It should not do any of the following yet:

- diffing
- scripting
- mutation

## Future Read-Only Backend Hands

- `check_kiosk_image`
- `analyze_kiosk_image`
- `compare_to_baseline`
- `generate_kiosk_profile`
- `summarize_kiosk_profile`

## Future Mutating / Build Jobs

These are design targets only and are not implemented yet:

- `build_kiosk_vm_from_profile`
- `test_kiosk_profile`
- `export_kiosk_image`
- `stage_kiosk_for_pxe`

## Profile Output Format

Design the generated profile directory like this:

```text
profiles/<name>/
  README.md
  package-additions.txt
  package-removals.txt
  enabled-services.txt
  disabled-services.txt
  config-diff-summary.md
  files/
  scripts/
  browser-policy/
  openbox/
  gdm/
  cups/
  domain/
  ephemeral-home/
  post-deploy.sh
  rebuild-plan.md
  test-plan.md
  risk-notes.md
```

## Things to Analyze Later

The read-only comparison phase should eventually inspect:

- installed packages
- apt sources
- users and groups
- systemd services
- GDM config
- X11 session hooks
- openbox config
- browser and kiosk launchers
- Chrome and Firefox policies
- CUPS and printer config
- SSSD, realmd, and domain join config
- tmpfs `/home/kiosk`
- kiosk-template
- power-button and logout wipe behavior
- Ninja or monitoring agent presence
- hostname and service-tag logic
- inventory reporting scripts
- custom scripts
- `/etc` changes

## Iris Behavior

Iris should:

- explain what makes the kiosk special
- separate intentional behavior from accidental cruft
- identify fragile, risky, stale, or private pieces
- recommend performance, stability, security, and usability improvements
- ask before converting analysis into scripts
- never claim a rebuild was tested unless the backend reports it
- never mutate the source image

## Risks and Open Questions

- Baseline OS version matters.
- Important behavior may live in scripts, policies, or service overrides rather than packages.
- Domain, printer, and browser policy data may contain secrets and needs strict redaction.
- The VM versus physical host boundary must be explicit.
- The generated profile must be reusable without leaking private configurations.

## 115 vs FM09

- 115 is the control plane for read-only analysis and Iris explanation.
- FM09 remains the build helper for heavy image or VM work.
- The first metadata phase can be controlled by 115.

## Recommended Next Step

Implement `analyze_kiosk_image_metadata` later as a small read-only metadata job.

That first step should only identify:

- image type
- OS version
- partitions
- read-only mountability
- package manager
- likely kiosk markers

Nothing else yet.
