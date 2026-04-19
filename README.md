# PRISM

Own your server again.

**Download and build a better one. We dare you.**

![PRISM Terminal Banner](assets/prism-banner.png)
*The PRISM identity banner — displayed on every login*

**P**rivate · **R**esilient · **I**ndependent · **S**ustainable · **M**odular

## What PRISM Is

PRISM is a private, resilient, independent home server platform for people who
want local services without surrendering control. It is built on Debian,
designed to stay root-accessible, and meant to explain itself instead of
hiding behind appliance theater.

It starts with one box. That matters. PRISM is not built around the assumption
that everyone needs a cluster, a rack, or an enterprise budget. The single-server
experience is the product. If local AI or heavier workloads justify expansion
later, PRISM can grow into that. If not, it should still stand on its own.

PRISM is also honest about hardware. It was born on recycled Dell OptiPlex
systems because those machines are cheap, available, and still useful. That does
not mean PRISM is trapped there. It works on recycled hardware, old gaming PCs,
and brand new machines too. The rule is simple: start with what you have, then
be honest about what that hardware can really do.

## What PRISM Stands For

### Privacy
Your data lives on your hardware, in your home, under your control.
Not on someone else's server. Not processed by someone else's AI.
Not logged, sold, or handed to advertisers.

Privacy in PRISM means local-first services, no telemetry, no phone-home
behavior, and full transparency about what is installed and what it does.
Iris runs on your hardware. Your searches go to your search engine.
Your passwords live in your vault.

### Resilience
A PRISM server should keep working when things go wrong.

That means services that restart automatically, honest error reporting,
no single points of failure that take everything down, and a system that
tells you what is happening instead of hiding failures behind a clean
interface. Iris is honest about problems. PRISM does not pretend
everything is fine when it is not.

### Independence
You should never need permission to use your own server.

Full root access always. No vendor lock-in. No subscription required to
keep using what you already installed. No cloud account needed to manage
your own machine. PRISM is built on Debian and open source tools that
have been around for decades and will be around for decades more.
You own it. You control it. Nobody can take it away.

### Sustainability
Every PRISM running on end-of-life hardware is a computer that did
not become e-waste.

PRISM's niche is giving working computers a second life as private
infrastructure. A recycled OptiPlex running PRISM is more useful than
a recycled OptiPlex in a landfill. Every private service running locally
is also a workload that did not get sent to a data center burning power
somewhere else. This is not nostalgia. It is a practical philosophy:
if a computer can still do useful work, it should.

### Modularity
PRISM starts with one box and adjusts services as you add or remove hardware.

Add a drive and Iris offers Jellyfin. Add a GPU and Stable Diffusion
becomes available. Ask for something your hardware can't do yet and
Iris tells you exactly what you'd need.

Nothing is locked in. The owner always knows what is installed,
why it is there, and how to change or remove it.

## Meet Iris

Iris is the first face of PRISM.

She is not supposed to be a gatekeeper, a mascot, or a black box. She is
the local guide who helps the owner understand what the machine is doing,
what services are installed, where things live, and what tradeoffs matter.

PRISM should always expose three transparent ways to interact with the
same system:
- Iris for guided explanation and setup
- Web GUI for visibility and daily management
- Terminal for full unrestricted control

If Iris is doing her job right, the owner ends up more informed,
not more dependent.

### Iris Personalities

Iris has a personality system. At first boot the owner chooses how
Iris talks to them:

- Professional — clean and direct
- Friendly — warm and encouraging
- Playful — light and witty
- Zen — calm and minimal
- Technical — detailed and precise
- Custom — define your own

This can be changed anytime. "Hey Iris, switch to zen mode."

The personality system also supports community themes — coordinated
voice, response style, and UI accent colors that anyone can build and
share. Think desktop themes from the Windows 95 era, but for your
AI assistant.

## Two Ways To Run

### PRISM Offline

The heavier image.

It ships with the major pieces already present:
- Ollama installed
- local model already included
- nginx and Iris chat UI already staged
- larger image, faster to use once booted

This is the version for people who want a self-contained artifact and
minimal download time after first boot.

On every first boot, after Iris is ready for the first time, PRISM plays
the Winamp llama clip exactly once.

*It really whips the llama's ass.*

This is not a joke about the software. It is a celebration of the fact
that the owner is running serious local AI on their own hardware.
It happens once. After that Iris greets normally per personality.

### PRISM Net

The lighter image.

It starts smaller, boots faster onto hardware, and downloads what it
needs on first boot while Iris guides the owner through setup in
the browser.

This is the version for people who want:
- a smaller image
- hardware-aware setup
- only the services that actually make sense for the machine
- a first boot flow that stays recognizably PRISM instead of
  collapsing into a sterile installer

## Three Ways To Get It

### 1. Build It

Clone the repo, inspect everything, and build your own image.

This is the most PRISM way to do it.

### 2. Flash It

Download a published image, write it to disk, boot it, and let
Iris take over from there.

### 3. Buy One Locally

PRISM is available prebuilt on recycled Dell OptiPlex hardware
in Eugene, Oregon.

- Plug it in
- Open a browser
- Meet Iris
- $100
- No subscription
- Ever

The hardware is recycled. The software is open source.
The data stays in your home.

If you are not in Eugene, the build instructions are right here.
Anyone can build one.

## What Runs On PRISM

### Core Services

- Vaultwarden — passwords and credential management
- AdGuard Home — DNS and ad blocking
- Nextcloud — files, sync, contacts, calendar, and photos
- SearXNG — private search
- Paperless-ngx — document archive and scanning destination
- Headscale — self-hosted private remote access
- nginx and fail2ban — base platform

These are not random checkboxes. They form the PRISM identity:
private daily-use tools, personal infrastructure, immediate value
without cloud dependence.

### Optional Services

- Jellyfin — when extra storage exists
- Stable Diffusion — when a usable GPU exists
- Gateway mode — when a second NIC exists
- Home Assistant
- Gitea
- Calibre

PRISM should stay opinionated. A smaller, better-supported service
list is better than a fake marketplace full of half-finished ideas.

## Built For Real Hardware

**PRISM's niche is giving new life to end-of-life computers that might
otherwise end up in a landfill — but it works fantastic on brand new
hardware too.**

That is not a marketing garnish. It is part of the product philosophy.

PRISM should be honest about hardware lifecycle, honest about
performance, and honest about upgrade paths. A recycled OptiPlex is
a real server if the software respects its limits. An old gaming PC
is a great PRISM machine if it has the GPU and RAM to justify heavier
local AI. A brand new machine is also fine. The point is not nostalgia.
The point is useful private computing on hardware people actually have.

## Hardware Spectrum

### Minimum Viable
- Any x86 computer
- 8GB RAM
- Core privacy services
- Small local model
- Limited, but genuinely useful

### Sweet Spot
- 32GB RAM small-form-factor machine
- Recycled Dell OptiPlex
- Full core service stack
- Strong local assistant experience
- The hardware PRISM was born on

### Power User — The Retired Gaming PC

An old gaming PC is one of the best PRISM machines available.

Full-size tower means real GPU options. Existing PSU is already sized
for a GPU. CPU and RAM are usually decent. And when someone upgrades
to a new gaming PC, the old one is sitting there doing nothing.

That machine can run a private AI assistant, a password manager,
private search, ad blocking, a media server, and local image generation
— all at the same time, for free, forever, without sending data anywhere.

Recommended specs:
- 32GB to 64GB RAM
- GPU with 8GB+ VRAM (RTX 3060 or better recommended)
- Any modern-ish x86 CPU

Even a modest GPU dramatically changes the experience. A GTX 1050 Ti
with 4GB VRAM showed 77% GPU utilization and interactive response speeds
on 3B models in our testing. A better GPU does proportionally better.

### High End
- 64GB RAM or more
- Modern high-end GPU
- Full-speed local AI
- Best PRISM experience with the fewest compromises

## A Note On Clustering

Clustering works well for running PRISM services across multiple machines.
It does not work well for AI inference on gigabit ethernet.

We tested this in order: exo failed on storage, llama.cpp RPC never
finished loading 70B across 5 nodes, and distributed-llama finally
proved 70B across 4 nodes — each requiring a dedicated second SSD for
model shard storage. Speed: 0.37 tokens per second, 56 minutes from
cold start to first response.

A single OptiPlex 7090 with 64GB RAM running llama.cpp was dramatically
faster than all of that.

For 405B we expanded to 12 nodes and 464GB combined RAM. It still failed.
Gigabit ethernet was the bottleneck, not the RAM. 10GbE would be required
and costs more than buying better hardware.

The network is always the bottleneck, not the RAM.

For AI inference: one good machine beats a cluster every time on gigabit.
For running services: clustering works fine and distributes load well.

See [hippynurd/llm-on-recycling](https://github.com/hippynurd/llm-on-recycling)
for the full honest benchmarks.

## Philosophy

PRISM should never become a black box.

The point is not to trap people inside a branded appliance. The point
is to give them a polished private server that still feels like theirs.

Principles:
- No telemetry
- Full root access always
- Built on Debian
- Fully open source
- Local-first services
- Honest hardware expectations
- Explain the why, not just the what

The tone matters too:
- direct
- honest
- warm
- never corporate
- never sterile

> Leave people less ignorant, or at least entertained.

## Status

| Component | Status | Notes |
|---|---|---|
| PRISM Offline v0.1 | ✅ Complete | Built, compressed, boot tested in VM, Iris responding |
| PRISM Offline boot test VM | ✅ Complete | Iris responded via nginx, 157 seconds on recycled VM hardware |
| PRISM Offline boot test real hardware | ⏳ Pending | 7020 bare metal test not yet done |
| PRISM Net v0.1 | ✅ Complete | Built, verified, compressed (1GB) |
| PRISM Net boot test | ⏳ Pending | VM and real hardware test not yet done |
| Native service installers | ✅ Complete | All 6 core services written |
| GitHub publication | ✅ Live | https://github.com/hippynurd/prism |

## Author

Built by [hippynurd](https://github.com/hippynurd) in Eugene, Oregon.

30 years in IT infrastructure. Electronics manufacturing veteran who
assembled processor boards for the Thinking Machines CM-5 — the first
computer to break the teraflop barrier. Oregon Country Fair IT
infrastructure volunteer for 30 years. ISP operator. Linux user since
before it was easy.

PRISM came out of a simple frustration: privacy-focused home servers
exist, but none of them are honest about what they are, what they cost,
and what hardware they actually need.

This one tries to be.

If you build a better one, show your work.
That is how this is supposed to work.
