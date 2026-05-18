# PRISM Community Post Drafts

These are draft posts. PRISM is alpha/dev, not production-ready.

## Mastodon / Fediverse

Draft:

I am building PRISM, a local-first home server project for old office PCs,
gaming desktops, and privacy-focused self-hosting.

The idea is simple: old computers still have work to do.

PRISM uses Iris, a local operator assistant, to explain what the machine can do,
what services make sense, what is blocked, and what should happen next. The goal
is not "AI magic"; it is private infrastructure people can understand and
control.

Current alpha work includes read-only hardware/status checks, install readiness,
blocker diagnosis, GPU/local-AI readiness, and a capability planner. Real
install jobs are still gated for later.

I am not calling it production-ready yet. I would like feedback from
self-hosting, Linux, privacy, and old-hardware people before it becomes easy to
try.

## Reddit / Self-Hosted Feedback Post

Title idea:

Building PRISM: a local-first home server assistant for old PCs, privacy basics,
and self-hosting

Draft:

I am working on PRISM, an alpha home-server platform aimed at turning old office
PCs or gaming desktops into private local infrastructure.

The goal is not to hide Linux. The goal is to make the machine explain itself.
PRISM has a browser assistant named Iris that uses backend facts as its source of
truth. Iris can explain hardware, read-only status, install readiness, blockers,
local AI/GPU readiness, and what the machine is a good fit for.

Current status:

- sanitized `/setup/state`
- read-only status check
- read-only install readiness
- read-only blocker diagnosis
- read-only AI runner readiness
- read-only capability planner
- generic job endpoints blocked publicly
- raw hardware endpoints blocked publicly

What is not ready:

- production install flow
- public image
- final security hardening
- polished docs
- broad hardware testing

I am especially interested in feedback on:

- what services should be first-class in a privacy-focused home server
- what old hardware profiles matter most
- how much the assistant should explain vs. stay out of the way
- safety boundaries for install jobs
- what would make you trust or distrust a project like this

This is not a "please run this in production" post. It is an architecture and
direction feedback request.

## Hacker News Show HN Later

Use later when alpha is tryable.

Title idea:

Show HN: PRISM, a local-first home server assistant for old PCs

Draft:

Show HN: I built PRISM, an alpha local-first home-server platform for turning
old office PCs and gaming desktops into private infrastructure.

PRISM uses Iris, a local operator assistant, to explain hardware, readiness,
blockers, and setup choices before changing the system. It is meant for people
who want self-hosted privacy services without needing to already know every
Linux/networking detail.

The current alpha focuses on safe read-only visibility:

- sanitized hardware state
- service readiness checks
- blocker diagnosis
- local AI/GPU readiness
- hardware-aware setup recommendations
- blocked generic job endpoints

It is not production-ready yet. Real installs are intentionally gated for later.

I am sharing this for architecture and usability feedback, especially around how
AI can act as a local operator without becoming a black box or surveillance
product.

## Local Linux / Homelab Group

Draft:

I am building PRISM, a local-first home-server project aimed at giving old PCs a
second life.

Think: retired office PC or gaming desktop becomes a private server for privacy
basics, files/backups, private search, password management, and possibly local
AI helpers if the hardware supports it.

The assistant, Iris, does not replace Linux or root access. It explains what the
machine sees, what is safe to try, what is blocked, and what hardware would help.

It is alpha/dev right now. I am looking for feedback from people who understand
real home networks, old hardware, Debian, nginx, systemd, self-hosting, and the
many ways "easy setup" can go wrong.

The principle is: private infrastructure people can understand and control.

