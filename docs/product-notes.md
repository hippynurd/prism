## PRISM Product Vision
PRISM is a private, resilient, independent home server platform built around the idea that people should be able to own their computing again without giving up usability. It starts with a single-server experience and can grow into a cluster when local AI or distributed workloads justify it. The base product should work well on one box. The cluster is optional, not mandatory.

Core values:
- Privacy
- Resilience
- Independence
- Sustainability
- Modularity

PRISM is designed around recycled hardware first, especially Dell OptiPlex systems that are cheap, available, and still powerful enough for real local services. The product should always remain:
- Open source
- Telemetry free
- Root accessible
- Transparent about what it installs and why

The guiding philosophy is:
"Leave people less ignorant, or at least entertained."

That means PRISM should educate without lecturing, automate without hiding, and always leave the owner in control.

## PRISM Philosophy
PRISM should never become a black box. The point is not to trap users inside a branded appliance. The point is to give them a server that feels polished while remaining theirs.

Principles:
- No black boxes ever
- Full root access always
- Built on Debian
- Fully open source
- No telemetry
- Your computer, your data, your rules

PRISM should expose three transparency modes:
- Iris
  For people who want guided help and plain-language explanations
- Web GUI
  For people who want a dashboard, service management, and visible status
- Terminal
  For people who want direct shell access and standard Linux administration

All three modes should describe the same system, not three different products. Iris should never hide what distro is underneath, what services are installed, where files live, or how to change anything manually.

## Hardware Tiers
PRISM should be honest about hardware lifecycle rather than pretending every box has the same future.

### 7020 Tier
- 7020 32GB: viable now, but end of life as a long-term platform
- Strong value as landfill diversion hardware
- Good fit for selling now while they are cheap and easy to source
- Strong fit for basic PRISM Solo use cases
- Good fit for recycled AI cluster nodes when RAM is sufficient

Positioning:
- This is the practical, rescued machine
- It does what PRISM needs today
- It may feel slow in 3-4 years
- It should be sold honestly, not oversold

### 7040 Tier
- 7040 16GB+: future ready
- DDR4 upgrade path
- Longer runway
- Better long-term solo server platform
- Better candidate for customers who want fewer compromises over time

Positioning:
- This is the stronger foundation
- It costs more, but buys more time
- Better for customers who care about longevity and upgrade headroom

### Cluster Tier
- 7020 cluster nodes: 16GB minimum per node
- Four 7020 nodes together are enough for a 70B-capable cluster setup in the PRISM framing we discussed
- Cluster should be marketed as optional expansion, not baseline requirement

Cluster message:
- Single server first
- Add nodes only when the owner wants more AI or distributed capacity

## The Rescued Server vs The Foundation
This is one of the strongest product-positioning frames from today.

### PRISM Solo 7020
"The rescued server"

Story:
- A useful machine saved from e-waste
- Good enough to run real private services
- Limited availability by nature
- A sustainability-forward purchase
- Best for buyers who appreciate value and honesty

This angle works because it does not hide the hardware age. It turns age into meaning:
- recycled
- practical
- honest
- useful now

### PRISM Solo 7040
"The foundation"

Story:
- A longer-life platform
- Better upgrade path
- Better runway for the same PRISM software experience
- Better fit for customers who want stability over more years

This angle works because it avoids pretending the 7040 is just a slightly better 7020. It is the more durable base for the same philosophy.

### Shared marketing principle
Be honest about lifecycle. Privacy-focused customers tend to respect honesty more than hype.

Key message:
"The 7020 is a great deal right now. It does everything PRISM needs today. In 3-4 years it might feel slow. The 7040 is a better long term platform. Your call."

## Marketing Angles
PRISM marketing should focus less on "AI appliance" language and more on ownership, privacy, sustainability, and practical local control.

Core angles:
- Privacy without subscriptions
- Local-first services
- Recycled hardware with a real purpose
- Honest lifecycle expectations
- Full ownership and transparency

Specific angles:
- 7020: "The rescued server"
- 7040: "The foundation"
- Cluster: local AI expansion when needed, not cloud dependence

PRISM should appeal to people who want:
- A private home server
- Something understandable
- Something repairable
- Something that does not report home
- Something they can inspect and change

## Naming
Primary brand:
- Server product name: PRISM

Node naming scheme:
- Use spectrum colors
- Red
- Orange
- Yellow
- Green
- Blue
- Indigo
- Violet

Why it works:
- Fits the PRISM identity naturally
- Memorable
- Visually and conceptually coherent
- Easy for people to understand in cluster mode

Beyond seven nodes:
- Use extended color names
- Or allow user-defined names

Customization rule:
- Fully customizable after setup
- The default naming should be friendly and thematic, not mandatory forever

## Iris AI Assistant
Iris is the local guide and onboarding assistant for PRISM. It should make the system approachable without turning into an opaque control layer.

Core design:
- Runs locally
- Uses Llama 3.1 8B Q4
- Starts with one-question onboarding
- Never asks more questions than necessary

Suggested onboarding options:
- Just set it up
- Home Server
- Power User
- Custom

Intent of each option:
- Just set it up
  Minimal questions, sane defaults, fast path
- Home Server
  Focus on common personal services and simple explanations
- Power User
  More visibility, more knobs, fewer hand-holding assumptions
- Custom
  Choose services and behavior explicitly

Iris should present itself as an assistant, not a gatekeeper. It should explain:
- What distro PRISM uses
- What services are installed
- Where data lives
- What ports and interfaces matter
- How to disable, replace, or reconfigure anything

### Three interfaces
PRISM should always expose:
- Iris chat
- Web GUI
- Terminal

These should complement each other:
- Iris for guided explanation and setup
- Web GUI for visibility and normal management
- Terminal for unrestricted control

## Service Catalog
The service catalog should be simple, opinionated, and understandable.

### Core services
Always installed:
- Vaultwarden
  Passwords and credential management
- AdGuard
  DNS and ad blocking
- Nextcloud
  Files, sync, and photo storage
- Whoogle or SearXNG
  Private search
- Paperless
  Document archive and scanning destination

These form the PRISM base identity:
- personal infrastructure
- private daily-use tools
- immediate value without extra complexity

### Optional add-ons
- Jellyfin
  Requires a hard drive and makes sense only when media storage exists
- Home Assistant
- Gitea
- Calibre

The add-on catalog should stay intentionally limited at first. A smaller, better-supported list is better than an endless marketplace.

## Development Path
### Phase 1: Build PRISM on one 7020

## Iris Audio - First Boot Soundbite

On every first boot, when Iris finishes loading and is ready
for the first time, play the Winamp soundbite:

"It really whips the llama's ass"

Reasoning:
- Iris always runs on Ollama (or llama.cpp underneath)
- It is always whipping the llama's ass regardless of model size
- Celebrates the fact that the user is running local AI on
  their own hardware
- Callbacks to Winamp theme culture of the Windows 95 era
- Fits "leave people less ignorant, or at least entertained"
- Works for 8B or 70B - it's always whipping

This is a first-boot-only soundbite, not every startup.
After that Iris greets normally per personality theme.
- Strip the current Mothership configuration down to a clean PRISM base
- Add the Iris setup wizard
- Make the system USB installable

Goal:
- prove the concept on one recycled box

### Phase 2: Test on a fresh 7020
- Clean install from scratch
- Verify Iris works
- Verify services auto-start correctly

Goal:
- prove that PRISM is reproducible and not just a hand-built demo

### Phase 3: GitHub
- Publish a strong README
- Include photos
- Include install instructions
- Include service catalog documentation

Goal:
- make the project legible and real to outsiders

### Phase 4: Show boss
- Working demo
- GitHub presence
- Cost breakdown
- Business case

Goal:
- present PRISM as a product direction, not just a technical experiment

## Business Model
The business case works because the hardware is cheap, the build is automatable, and the story is differentiated.

Estimated economics:
- Hardware cost: $50-80 per unit
- Build time: automated, roughly 20 minutes

Possible product pricing:
- PRISM Solo 7020: $150-200
- PRISM Solo 7040: $200-250
- PRISM AI cluster: $300-500

Revenue can also come from:
- Setup services
- Support services
- Node expansion sales
- Upgrade consultations

The real value is not just the hardware markup. It is:
- curation
- privacy positioning
- easier setup
- good defaults
- honest support

## Key Insight
The most important product honesty statement from today is:

"The 7020 is a great deal right now.
It does everything PRISM needs today.
In 3-4 years it might feel slow.
The 7040 is a better long term platform.
Your call."

That statement captures the tone PRISM should keep:
- honest
- practical
- confident without pretending
- respectful of the customer's judgment

## Iris - The AI Assistant
### Name Origin
- Iris: Greek goddess of the rainbow
- PRISM splits light into the spectrum
- Iris IS the spectrum - she guides you through it
- Also: part of the eye (vision, clarity)
- Also: a beautiful flower
- The name is intentional - no acronym needed
- PRISM creates the spectrum, Iris embodies it

### Personality System
Users choose Iris personality at first boot:
- Professional: clean and direct
- Friendly: warm and encouraging
- Playful: jokes and humor during setup
- Zen: calm and philosophical
- Technical: detailed and precise
- Custom: user defines their own

Can be changed anytime:
- "Hey Iris, switch to zen mode"
- Via web GUI settings
- Via terminal config

### Philosophy
- Iris should feel like a person not a product
- Warm, human, occasionally surprising
- "Leave people less ignorant, or at least entertained"
- Kids jokes optional but encouraged 😄
- Never corporate, never sterile, never boring

## Browser Privacy Policies

### The Problem
Stock browser defaults are not privacy friendly:
- Chrome sends browsing data to Google
- Telemetry enabled by default on all browsers
- Third party cookies allowed
- DNS queries go to Google/ISP by default
- Most users never change any of this

### PRISM Browser Policy Philosophy
Privacy improvements WITH user freedom:
- Better defaults, not locked down
- User CAN change anything (not a kiosk)
- Transparent about what changes and why
- Explains WHY not just WHAT

### Key Distinction
Kiosk policy: locks everything down, user CANNOT change
PRISM policy: better defaults, user CAN change

### Privacy Improvements Applied
- Telemetry disabled
- Third party cookies blocked
- DNS over HTTPS -> points to local PRISM AdGuard
- Safe browsing privacy mode
- No cloud sync by default
- Sponsored content disabled
- Tracking protection enabled

### User Freedom Preserved
- Can install any extension
- Can visit any site
- Can override any setting
- Not restricted, just better defaults

### DNS Integration
Browser -> DNS query -> PRISM AdGuard (local)
-> Ads blocked before they load
-> Trackers blocked before loading
-> No Google/ISP seeing queries
-> All private, all local

### Browser Templates
Structure:
`/prism/browser-policies/`
- `firefox/privacy.json`
- `firefox/security.json`
- `firefox/recommended.json`
- `chrome/privacy.json`
- `chrome/security.json`
- `edge/privacy.json`
- `brave/`
  minimal tweaks needed (already privacy focused)

### Iris Browser Deployment
Iris detects installed browsers and asks:

"I found Firefox and Chrome.
Would you like me to apply privacy
settings to both?
You can still change anything."

Options presented:
- `Yes please`
- `Show me what changes`
- `Skip`

### Show Me What Changes
Iris explains each change in plain language:
- What it does
- Why it helps privacy
- That user can change it anytime

### Kiosk Policy Reuse
Existing kiosk browser policy work is reusable:
- Kiosk: more restrictive, user cannot change
- PRISM: privacy focused, user can change
- Same policy format, same deployment
- Different values, different philosophy

### GitHub Opportunity
`prism-browser-policies` as standalone repo:
- Ready to deploy templates
- Firefox, Chrome, Edge support
- Privacy focused, user friendly
- Documentation explaining each setting
- Valuable to IT community even without PRISM

## Idle Resource Donation (BOINC Integration)

### Concept
PRISM detects idle computing resources and offers to donate them to scientific research. With full transparency and user consent. Not a virus - the opposite of a virus.

### The PRISM Difference vs Traditional Spreading
Virus: spreads without consent ✗
PRISM agent: asks first ✓

Virus: hides what it does ✗
PRISM agent: shows everything ✓

Virus: cannot be removed ✗
PRISM agent: remove anytime ✓

Virus: serves attacker ✗
PRISM agent: serves user's chosen cause ✓

### Implementation Model
Based on proven BOINC/Folding@home model:
- Folding@home: millions of volunteers
- SETI@home: ran 20+ years
- Model is proven, people love it

### Iris Integration
Iris asks:

"Your computers are idle most of the day.
Want to donate that time to science?

Available projects:
🔬 Folding@home (cancer/Alzheimer's research)
🌍 Climate modeling
🔭 SETI (searching for extraterrestrial life)

You stay in full control. Stop anytime."

### Technical Implementation
BOINC already packaged in Debian:
`apt install boinc-client`

Iris configures project and shows stats in dashboard.

### Dashboard Stats
"Your PRISM has contributed:
847 hours to Alzheimer's research this month
Equivalent to X lab hours"

### Classification
- Nice to have
- Not v1
- Planned for future release
- Simple to implement when ready

## Feature Classification

### PRISM v1 Must Have
- Debian base install
- Core privacy services
  (Vaultwarden, AdGuard, Nextcloud, Whoogle/SearXNG, Paperless)
- Iris wizard with personality selection
- Browser privacy policy deployment
- USB installable
- Web GUI
- Full transparency about all changes

### PRISM v1 Nice to Have
- BOINC/Folding@home integration
- Network agent for other devices
- Idle resource donation

### PRISM v2 and Beyond
- Advanced cluster management
- Computer factory integration
- OS deconstruction and recipe generation
- Full PRISM product line

## Upgrade Advisor System

### Concept
Iris monitors hardware continuously.
When new hardware is detected, Iris notifies
the user and explains what's now possible.
Two questions Iris always answers:
  "What can I do with what I just added?"
  "What do I need to do what I want?"

### Hardware Detection
Iris monitors automatically:
  New drives appearing
  New USB devices
  New network interfaces
  RAM changes
  GPU added
  Bluetooth dongles
  WiFi adapters
  UPS connected

When something new appears:
  Iris notifies you
  Explains what's possible
  Offers to configure it
  No manual setup needed

### Upgrade Categories

Storage (add hard drive):
  Jellyfin: private media streaming
  Immich: private Google Photos replacement
  Nextcloud: expanded file storage
  Paperless: document archive
  Navidrome: private Spotify replacement
  Calibre: ebook library
  Time Machine: Mac backup target
  qBittorrent: download manager

Graphics Card:
  Stable Diffusion image generation
  Faster AI inference
  Jellyfin video transcoding
  Faster Whisper STT

More RAM:
  Bigger AI models
  More simultaneous services
  Better performance overall
  Larger caches

Second NIC:
  Gateway/firewall mode
  Better network separation
  Direct cable modem connection

Cluster Nodes:
  70B AI models
  Image generation without GPU
  Video render farm
  More parallel tasks

Bluetooth Dongle:
  Iris speaks through Bluetooth speaker
  Bluetooth keyboard/mouse support
  Presence detection:
    Phone detected = you're home
    Phone gone = you're away
  Home automation triggers
  Private, local, no cloud

WiFi Adapter:
  Wireless client support
  Guest network
  Backup internet connection
  Location independent setup
  Failover if wired goes down

UPS (Uninterruptible Power Supply):
  Safe shutdown on power loss
  Protects data integrity
  Iris monitors battery level
  Alerts before shutdown
  Gracefully suspends cluster nodes
  Critical for data integrity

### Iris Upgrade Advisor Example
User adds hard drive:

Iris: "I found a new 2TB drive!

Here's what I can do with it:

📺 Media Server (Jellyfin)
   Stream movies and TV privately

📸 Photo Library (Immich)
   Private Google Photos replacement

💾 More file storage
   Expand your Nextcloud storage

📚 Book library (Calibre)
   Manage and read ebooks

🎵 Music server (Navidrome)
   Private Spotify replacement

🔄 Automatic backups
   Time Machine for Mac users

What would you like to enable?
You can do multiple!"

### Cost Guidance
Iris provides realistic cost estimates:
  "A 2TB hard drive costs:
    New: ~$50-60
    Used: ~$20-30 (thrift store)
    
   A Bluetooth dongle:
    New: ~$10
    Used: ~$2-5
    
   More RAM (DDR3 8GB):
    Used: ~$8-15 per stick
    NextStep or thrift store"

### Upgrade Advisor Menu
Main dashboard option:
  "What can I add to do more?"
  Shows current hardware
  Shows possible upgrades
  Shows what each enables
  Shows where to get it cheap
  Iris configures automatically when added

## Mobile / Phone Integration

### Core Apps (work immediately)
Nextcloud mobile app:
  Auto photo/video upload ✓
  File sync ✓
  Contacts sync ✓
  Calendar sync ✓
  Private Google Photos replacement ✓
  Works over Tailscale remotely ✓

Bitwarden/Vaultwarden app:
  All passwords on phone ✓
  Auto fill in apps ✓
  Works over Tailscale remotely ✓

Jellyfin mobile app:
  Stream your media on phone ✓
  No Netflix needed ✓

Navidrome + Ultrasonic app:
  Your music on phone ✓
  No Spotify needed ✓

### Talking to Iris from Phone

Option 1: Browser (v1)
  Open PRISM web interface
  Chat via browser
  Works on any phone
  No app needed
  Voice via browser microphone
  Whisper STT processes it
  Iris responds
  Piper TTS speaks back

Option 2: Tailscale
  Connect phone to Tailscale
  Access PRISM from anywhere
  Chat with Iris remotely
  As if you never left home

Option 3: Dedicated PRISM app (future)
  Single app for everything
  Not v1
  Community contribution welcome

### Video Upload
Record video on phone
Nextcloud auto uploads
Available on PRISM immediately
Never goes to Google/Apple cloud
Private and local

### Private Notifications
Gotify: self hosted push notifications
  "Storage is 80% full"
  "Failed login attempts detected"
  "Power outage - UPS active"
  "AI job finished"
  "Iris has a message for you"
  
No Google Firebase needed
Private push notifications
Works over Tailscale

### Presence Detection
Phone Bluetooth -> PRISM detects you're home
Phone leaves network -> PRISM knows you're away

Home Assistant integration:
  Arrive home -> lights on, welcome mode
  Leave home -> security mode, power saving
  All local, all private
  Phone never reports to anyone

### Remote Access via Tailscale
At home:
  Phone on WiFi -> direct fast connection
  Everything local and fast

Away from home:
  Phone on Tailscale -> encrypted tunnel
  Everything still works
  Iris still accessible
  Files still accessible
  Passwords still accessible
  As if you never left home

### Single App Vision (future)
V1: separate apps per service
  Nextcloud for files/photos
  Bitwarden for passwords
  Jellyfin for media
  Browser for Iris

V2: single PRISM companion app
  Chat with Iris
  Browse files
  View photos
  Stream media
  Server status
  Notifications
  Everything in one place

### Contact and Calendar Sync
Phone contacts -> PRISM -> all devices
No Google sync needed
Works with any phone
Standard protocols (CardDAV/CalDAV)
Nextcloud handles this

### Authentication
Authelia: single sign on
  One login for all PRISM services
  2FA support
  Works on mobile
  No Google account needed

## Iris Themes System

### Concept
Iris personalities work like classic desktop themes - coordinated style across voice, responses, sounds, and UI that express a personality or pop culture reference.

Like the old desktop themes:
  Icons, wallpaper, sounds, cursors
  All coordinated into one style
  Evil Dead theme: computer said "Groovy!"
  
Iris themes coordinate:
  Voice (TTS voice selection)
  Personality and response style
  Greeting phrases
  Success messages
  Error messages
  Idle phrases
  UI accent colors

### Built-in Themes

🤵 Professional (default)
   Clean, direct, business-like

😊 Friendly
   Warm and encouraging

😄 Playful - Frog Mode
   Kids jokes during setup
   Named after Frog from Oregon Country Fair
   "Why did the router go to therapy?
    Too many connections!"

🧘 Zen
   Calm and philosophical
   "Your data flows like water"

🤓 Technical
   Detailed and precise
   Full technical output

😤 Mutabot
   Security/privacy focused
   Muta/SomeOrdinaryGamers energy
   "Bro do you know what Google
    was doing on that one page?"
   Based on privacy content transcripts

🪚 Groovy - Evil Dead
   "Installation complete."
   "GROOVY."
   "Good. Bad. I'm the one
    with the server."
   "We're gonna need a bigger chainsaw"

🤖 Cherry 2000
   Retro companion AI aesthetic
   Warm, helpful, slightly futuristic
   1987 film basically predicted Iris
   Personal AI + privacy + independence
   The movie IS the PRISM pitch

🔴 HAL 9000 - 2001
   "Good morning.
    I'm completely operational and
    all my circuits are functioning
    perfectly."
    
   Error: "I've just picked up a fault
           in the AE35 unit."
           
   Shutdown: "I'm afraid I can't let
              you do that Dave."
              
   Power save: "Daisy... Daisy..."
   
   Suspicious login: "I know you were
    planning to disconnect me."
   
   HAL is basically PRISM:
     Home computer ✓
     Manages all systems ✓
     Monitors everything ✓
     Talks to you ✓
     Has a personality ✓
     Without the murderous tendencies ✓
     With better privacy settings ✓

🌌 Hitchhiker's Guide
   "Don't Panic. Your server is fine."
   "Also, 42."
   Error: "This is clearly some strange
           usage of the word 'fine'
           that I wasn't previously aware of"
   Setup complete: "So long and thanks
                   for all the privacy."

🖖 Star Trek
   "PRISM online. All systems nominal."
   Installing: "Initializing subroutines"
   Error: "I'm giving her all she's
           got captain"
   "Make it so."

### Theme Format
Simple config file:
  Response templates
  Voice settings
  Color scheme
  Sound effects
  
Easy enough for anyone to create
Share on GitHub
Install via Iris:
  "Hey Iris install the [theme name] theme"

### Community Themes
Anyone can build a theme
Share on GitHub
PRISM community builds library
Like WordPress/VSCode themes
But for your private AI assistant

Users:
  Make themes ✓
  Share themes ✓
  Rate themes ✓
  Fork themes ✓
  Improve themes ✓

### Theme Marketplace Vision
Community maintained theme library
Install directly from Iris
"Hey Iris what themes are available?"
"Hey Iris install Hitchhiker's Guide"
Browse themes in web GUI
Rate and review themes
Submit your own

### The Deeper Connection
These themes connect PRISM to:
  Pop culture people love
  Familiar personalities
  Emotional connection to setup process
  Makes privacy accessible and fun
  
"Leave people less ignorant
 or at least entertained" ✓

## Hardware Philosophy - Any Computer Welcome

### Core Principle
PRISM is not limited to recycled Dell hardware.
It works on any x86 computer.
Born from recycled hardware, designed for everything.

"Start with what you have.
 Add what you need.
 Nothing wasted.
 Nothing limited."

### Hardware Spectrum

Minimum viable:
  Any x86 computer
  8GB RAM
  Core privacy services only
  Small AI models (3B)
  Limited but genuinely useful
  Still better than nothing

Sweet spot (reference hardware):
  32GB RAM SFF
  Recycled Dell OptiPlex
  Full service stack
  7B-13B AI models
  The hardware PRISM was born on

Power user:
  Old gaming PC
  GPU (GTX 1070, 1080 etc)
  32-64GB RAM
  Full image generation
  Faster AI inference
  GPU acceleration

High end:
  7090 or newer
  64GB RAM
  Modern GPU
  Full 70B inference solo
  Everything at full speed

Unusual but works:
  Old Mac Pro
  Tons of RAM
  PCIe slots
  PRISM handles it

### GPU Reality - Corrected

SFF computers:
  Low profile GPU only
  GT 1030: too old for AI
  Limited GPU options
  Cluster nodes compensate

Tower/gaming computers:
  Full size GPU available
  GTX 1070: usable for AI ✓
  GTX 1080: good for AI ✓
  RTX 2070+: great for AI ✓
  RTX 3090: excellent for AI ✓

Iris GPU assessment:
  Identifies GPU model
  Honest about capability
  "Your GTX 1080 can run
   Stable Diffusion well"
  "Your GT 1030 is too old
   for image generation"
  "Your RTX 3090 can run
   70B models with GPU acceleration"

### 8GB RAM Reality

What works well:
  AdGuard ✓
  Vaultwarden ✓
  SearXNG ✓
  Nextcloud (tight but works) ✓
  Small AI model (3B) ✓
  Jellyfin (maybe) ✓

What's challenging:
  Everything simultaneously
  Bigger AI models
  Multiple heavy services

Iris is honest:
  "With 8GB RAM I can run
   core privacy services
   and a small AI model.
   
   Adding more RAM would enable:
   Bigger AI models
   More simultaneous services
   Better performance
   
   8GB DDR3 sticks cost ~$8-15
   at thrift stores or NextStep"

### Iris Hardware Assessment
On first boot Iris surveys:
  CPU: speed, cores, generation
  RAM: amount and speed
  Storage: type and size
  GPU: model and VRAM
  Network: interfaces available

Then gives honest report:
  "Here's what runs great"
  "Here's what runs okay"
  "Here's what needs more hardware"
  "Here's what to add for X"

No surprises
No disappointment
Honest from the start
Sets correct expectations

### The Recycling Angle - Not a Limitation
PRISM story:
  Born from recycled hardware
  Works on anything
  Honest about capabilities
  Grows with your hardware

The goal:
  Keep computers out of landfill longer ✓
  But not at the cost of capability ✓
  A gaming PC with a good GPU
  running PRISM is perfect ✓
  A brand new computer
  running PRISM is perfect ✓
  A recycled Dell OptiPlex
  running PRISM is perfect ✓

### PRISM Philosophy Updated
Not: "designed for recycled Dells"
But: "designed to work with what you have
      and be honest about what that means"

Old gaming PC with GPU?
  Here's what that enables

8GB laptop someone retired?
  Still useful, here's what works

Brand new high end desktop?
  Everything at full speed

Recycled OptiPlex from the pile?
  The sweet spot, proven hardware

### Differentiation from Umbrel/CasaOS
They assume decent hardware
PRISM works on anything
AND tells you honestly
what that means for you

Iris hardware assessment is unique:
  No other home server does this
  Honest capability reporting
  Upgrade path always visible
  No surprises after install

### Updated PRISM Tagline Options
"Your private server. Any computer. Honest about what it can do."

"Born from recycled hardware.
 Works on anything.
 Honest about everything."

"Your computer. Your data. Your rules.
 Whatever computer you have."
## PRISM Offline v0.1 — BUILD COMPLETE
Date: 2026-04-14

### Image
- Raw: build workspace output raw image (64GB in the recorded build)
- Compressed: build workspace compressed image (8.4GB in the recorded build)
- SHA256 raw: 28f545c548c385b1408d0f9f5ca519b61b993cd1abac7e482d45b51a31cafe87
- SHA256 gz:  6a754ca77c2199626d371ee0e44e1e335a2be13f56c816404bb85dfc0fe7c3a3

### Contents
- Debian base, GPT, EFI 512MB, Root 63.5GB
- GRUB bootloader
- Hostname: prism / Root pw: prism
- SSH: PermitRootLogin yes, PasswordAuthentication yes
- Ollama: /usr/local/bin/ollama (symlink: /usr/bin/ollama)
- Ollama service: enabled
- Model: llama3.1:8b (4.6GB)
- nginx: serving Iris chat UI at /var/www/html/index.html
- /api/ proxied to 127.0.0.1:11434
- Iris system prompt baked into UI

### Status
- Not yet boot tested in VM
- Ready for testing when needed

## PRISM Net v0.1 Architecture Decisions
PRISM Net exists to keep the image small without making the product feel smaller.

The goal is not to ship a stripped-down installer that forgets what PRISM is.
The goal is to let a lighter image become a full PRISM system in front of the owner, with Iris guiding the process honestly.

### Iris As Setup Wizard On All Hardware
Decision:
- Iris is the setup wizard on every supported machine, including 8GB systems.

Why:
- Iris is part of PRISM identity, not an optional luxury layer.
- Even smaller machines still have enough headroom to run a lightweight local model during setup.
- Falling back to a sterile scripted wizard on lower-end hardware would break the product philosophy.

Tradeoff:
- Setup on low-RAM machines still needs careful model selection and honest expectations.
- This is worth it because the user experience stays recognizably PRISM from the first boot.

### 1B Model For Setup, Switch After
Decision:
- PRISM Net always starts setup on `llama3.2:1b`, then switches to the right long-term model after hardware-aware setup is complete.

Why:
- `1b` is fast to pull, light on RAM, and good enough to guide setup.
- It leaves room for downloads, package installs, and browser-based interaction even on 8GB hardware.
- This lets Iris appear immediately instead of making the user wait for a larger model before setup even begins.

Tradeoff:
- Setup-mode Iris is not the strongest model PRISM can run.
- That is acceptable because setup needs responsiveness and stability more than maximum answer quality.

### Native systemd Over Docker
Decision:
- PRISM Net should prefer native installs and systemd services over Docker wherever practical.

Why:
- Native services are easier to inspect, understand, and debug.
- This better fits the PRISM promise of transparency and root accessibility.
- It avoids hiding important behavior inside container glue on a system that is supposed to educate the owner.

Tradeoff:
- Native install paths are more work to design and maintain.
- That extra work is justified because it keeps the system more honest and more understandable.

### Web UI Over Terminal Whiptail
Decision:
- PRISM Net setup should happen in the browser with Iris, not in a terminal-driven whiptail flow.

Why:
- A browser gives Iris room to explain choices, report progress, and stay human.
- It is easier for normal users to understand and trust.
- It preserves the three-interface philosophy: Iris, web GUI, and terminal all describe the same system.

Tradeoff:
- Browser setup requires nginx, a backend, and a more deliberate firstboot flow.
- That complexity is acceptable because the result is more coherent as a product.

### RAM-Based Model Selection
Decision:
- Final Iris model selection is based on available RAM:
  - 8GB class -> `llama3.2:1b`
  - 16GB class -> `llama3.2:3b`
  - 32GB class -> `llama3.1:8b`

Why:
- PRISM should be honest about hardware reality instead of pretending one model fits everything.
- The owner should get the strongest practical local model for their machine without being pushed into instability.
- This keeps the recommendation simple enough to explain in one sentence.

Tradeoff:
- Hardware tiers are blunt and not perfect.
- That is still better than fake precision or overselling what small machines can do.

### Hardware Detection Approach
Decision:
- PRISM Net setup detects RAM, extra disks, GPU presence, and NIC count at first boot, then uses that data to guide recommendations.

Why:
- Optional services should only be offered when they actually make sense on the detected machine.
- This keeps recommendations grounded in real hardware instead of generic menus.
- It supports honest setup paths:
  - extra disk -> Jellyfin makes sense
  - GPU -> Stable Diffusion becomes worth offering
  - second NIC -> gateway mode becomes relevant

Tradeoff:
- Detection logic will never be perfect across every odd hardware edge case.
- That is acceptable as long as PRISM stays explicit about what it found and why it is recommending something.

### Two nginx Configs Approach
Decision:
- PRISM Net should use two nginx configurations:
  - setup mode
  - normal Iris mode

Why:
- First boot is a real product state, not just a hidden flag.
- Setup mode needs different routes and proxies than the normal assistant mode.
- Keeping the configs separate makes the switch easy to inspect, easy to debug, and easy to reason about.

Tradeoff:
- There are two files to maintain instead of one.
- That is a small price for clarity, especially in a system that is trying not to become a black box.

## Power Management — Core Feature, Not Optional

PRISM must handle power management intelligently.
Sustainability is a core PRISM value, not an afterthought.

At scale — thousands or millions of PRISM installations —
idle machines burning unnecessary electricity is a real
environmental cost that contradicts the product philosophy.

Requirements:
- Detect idle state and reduce power automatically
- Wake on demand when needed
- Iris reports power usage honestly
- User sees exactly what is consuming power and why
- Opt-in compute donation (BOINC etc) uses idle power productively
- If not donating compute, machine should sleep not burn

Known challenges:
- BIOS variance across hardware (WOL reliability varies)
- FM03 A04 BIOS works, FM04 A07 does not
- SSH sessions can prevent sleep
- Need Kill-A-Watt measurements for real numbers

Practical reality:
- There may not be one power-management solution that fits every machine
- PRISM should solve power management the best it can per computer
- Detect actual hardware capability first, then choose the most honest supported path
- Do not promise wake behavior on machines that cannot do it reliably
- Iris should explain what this specific machine can and cannot do
- Per-machine honesty is better than fake global consistency

This must not get lost. It is important at personal scale
and critical at product scale.
