# PRISM Public README Draft

One-sentence pitch:

PRISM turns old office PCs, old gaming computers, and everyday Linux boxes into
private local-first home servers guided by Iris, a local operator assistant that
explains what the machine can do before it changes anything.

## What PRISM Is

PRISM is an alpha home-server platform for people who want private
infrastructure they can understand and control.

It is built around a simple idea: old computers still have work to do. A retired
office PC can block ads, host private search, store files, run a password vault,
or act as a small home server. A gaming PC with a GPU can also become a local AI
helper box. PRISM tries to make those options visible without hiding the Linux
system underneath.

PRISM is not production-ready yet. It is active development work.

## Why PRISM Exists

Most people do not lack computers. They lack approachable, trustworthy
infrastructure.

Self-hosting often assumes the user already understands Linux, networking,
storage, DNS, TLS, backups, and service operations. PRISM aims to keep the power
of Linux while making the machine explain itself.

The goal is not a locked-down appliance. The goal is private infrastructure that
people can inspect, repair, and learn from.

## What Iris Does

Iris is the user-facing local operator assistant for PRISM.

Iris should:

- explain what hardware PRISM found
- explain what the machine is good for
- report backend status using real system checks
- diagnose blockers before setup continues
- recommend safe next steps
- ask for goals before system-changing actions
- distinguish recommendations from installs

Iris should not:

- pretend work happened when it did not
- hide Linux details
- install services without explicit confirmation
- expose secrets or raw hardware identifiers
- replace root access

Current Iris work focuses on regular Iris plus PRISM eyes/hands on the 115 dev
server. Tiny Iris is frozen and preserved for future CPU/non-GPU mode work.

## What Works Today

Current alpha capabilities include:

- sanitized `/setup/state`
- read-only PRISM status check
- read-only install readiness check
- read-only install blocker diagnosis
- read-only AI runner readiness check
- read-only Iris capability planner
- public blocking for unsafe generic job and raw hardware endpoints
- live dev deployment workflow from MotherShip to the 115 PRISM dev server
- lightweight checkpoint strategy for small config/status snapshots

The capability planner lets Iris answer questions like:

- "What can this PRISM box do?"
- "What should I install?"
- "What is this hardware good for?"
- "Can this machine use GPUs for local AI helpers?"

## What Is Not Ready Yet

PRISM is not ready for general production use.

Not ready yet:

- final gated install flow
- production security hardening
- image-clean/finalization
- user password finalization
- polished public setup instructions
- stable service catalog
- backup/restore automation beyond lightweight checkpoints
- broad hardware test matrix

Real install jobs are intentionally not exposed publicly yet.

## Hardware Philosophy

PRISM starts with what people already have.

Good candidates:

- old office PCs
- recycled Dell OptiPlex-style machines
- old gaming PCs
- storage-heavy desktops
- GPU machines for local AI/helper workloads

Optional GPUs help local AI, coding helper models, media workflows, and possibly
image generation. They are not required for privacy basics.

Weak machines still matter. Tiny Iris is preserved for a future lightweight
CPU/non-GPU path, but that work is frozen for now.

## Privacy And Local-First Philosophy

PRISM treats privacy as an architectural requirement, not a theme.

Principles:

- local first
- no unnecessary cloud dependency
- no telemetry assumption
- no vendor lock-in
- full root access remains available
- services should be explainable
- backend facts should be sanitized before reaching the browser
- AI should act as a local operator, not a surveillance product

## Alpha Warning

This repository contains active development work.

Expect rough edges, incomplete docs, and internal dev assumptions. PRISM is being
built in public, but it is not yet a polished distribution.

Do not treat the current dev server IP, deployment scripts, or temporary SSH
bootstrap paths as production architecture.

## Screenshots Needed

Needed before replacing the main public README:

- Iris first boot intro
- hardware summary
- "Check PRISM status"
- "Are we ready to install services?"
- "Why is AdGuard blocked?"
- "Can this machine use GPUs for local AI helpers?"
- "What can this PRISM box do?"
- endpoint safety proof showing blocked `/setup/jobs`
- architecture diagram

## Roadmap

Near term:

- polish regular Iris browser wording
- improve capability planner presentation
- define canonical PRISM service catalog
- design gated install actions without exposing generic jobs

Later:

- implement consent-gated installs
- image-clean lifecycle
- credential finalization
- remove dev SSH keys before finalization
- hardware test matrix
- Tiny Iris CPU/non-GPU path when unfrozen
- public tryable alpha image

## Follow / Contribute Later

PRISM is not asking people to run it in production yet.

Good early feedback areas:

- architecture review
- privacy and endpoint safety review
- self-hosting service catalog ideas
- old hardware test reports
- Iris wording and UX feedback
- docs clarity

Contribution instructions will come after the alpha path is easier to try.

