# MotherShip PRISM Contamination Audit - 2026-05-16

Audit run from MotherShip on 2026-05-18.

Scope was MotherShip only. No SSH to 192.168.14.115 was performed. No files,
services, packages, nginx state, PRISM backend jobs, passwords, SSH config, keys,
frontend, backend, Ollama, or systemd state were changed. The only intentional
write from this audit is this report.

Sensitive values are not included. Device-specific iPXE hardware identifiers
found inside nginx config were redacted from this report.

## Executive Summary

Risk level: low to medium.

The confirmed unwanted change is the live MotherShip login MOTD script:

- `/etc/update-motd.d/10-prism`
- `/etc/update-motd.d/10-prism.backup-20260516-color-fix`

The installed MOTD is byte-identical to the repo file at:

- `/vault/pve-media/projects/prism/net/motd/10-prism`

The likely cause was a mistaken local/live deployment during the 2026-05-16
PRISM MOTD color-fix task. The task documentation explicitly says the validated
script was installed to `/etc/update-motd.d/10-prism` "on this host"; because
the audit was performed on MotherShip and the live file timestamps match that
task, "this host" appears to have been MotherShip, not 192.168.14.115.

No evidence was found that the PRISM backend, frontend, Iris nginx site, Ollama,
PRISM systemd services, PRISM cron jobs, or packages were installed or changed
on MotherShip during the last 48 hours.

MotherShip appears functionally affected only cosmetically by the SSH login MOTD.
Existing older PRISM-related MotherShip nginx iPXE chain helpers and PRISM state
directories are present, but their timestamps predate the MOTD task and they do
not look like new contamination from the 2026-05-16 MOTD change.

## How The PRISM MOTD Got Installed

Confirmed live file metadata:

```text
/etc/update-motd.d/10-prism
type=regular file
mode=755
owner=root:root
size=1831
mtime=2026-05-16 08:35:49 -0700
ctime=2026-05-16 08:35:49 -0700
sha256=e7c861c5e6c31ab6b28bd7ffa7fcda28f9de83134559a1435c59d3af38e9c21f
```

Repo source metadata:

```text
/vault/pve-media/projects/prism/net/motd/10-prism
type=regular file
mode=755
owner=root:root
size=1831
mtime=2026-05-16 08:35:09 -0700
ctime=2026-05-16 08:35:25 -0700
sha256=e7c861c5e6c31ab6b28bd7ffa7fcda28f9de83134559a1435c59d3af38e9c21f
```

The checksums match exactly.

Backup marker:

```text
/etc/update-motd.d/10-prism.backup-20260516-color-fix
type=regular file
mode=644
owner=root:root
size=83
mtime=2026-05-16 08:35:49 -0700
```

The backup marker says no previous `/etc/update-motd.d/10-prism` existed before
the 2026-05-16 color-fix deployment.

Relevant git commit:

```text
c5878dedf96bffbf2ce214a49cd4170c47c4fb26
Date: 2026-05-16 08:36:34 -0700
Subject: fix: restore colored PRISM MOTD
Files:
  A docs/PRISM_MOTD_COLOR_FIX_20260516.md
  M net/motd/10-prism
```

The commit occurred less than one minute after the MotherShip live MOTD file was
created.

Relevant task document:

- `/vault/pve-media/projects/prism/docs/PRISM_MOTD_COLOR_FIX_20260516.md`

That document states:

- the live `/etc/update-motd.d/10-prism` script was missing
- the repo source `net/motd/10-prism` was changed
- the validated script was installed to `/etc/update-motd.d/10-prism` with mode
  `0755`
- no packages were installed
- no services were restarted
- no backend jobs were triggered
- no network calls were added
- the backup path was `/etc/update-motd.d/10-prism.backup-20260516-color-fix`
- no previous live file existed on "this host"

Conclusion: the live PRISM MOTD was installed directly on MotherShip during the
2026-05-16 MOTD color-fix work, probably because the task treated the current
host as the live PRISM host.

## Install And Deploy Script Review

`/vault/pve-media/projects/prism/scripts/install-prism-net-assets.sh` installs
PRISM Net files into a caller-supplied `ROOTFS`. It creates PRISM app paths,
nginx sites, systemd units, setup jobs, and MOTD content under that root.

Important finding: the script currently installs the MOTD source to:

```text
$ROOTFS/etc/motd
```

It does not install:

```text
$ROOTFS/etc/update-motd.d/10-prism
```

Therefore, the observed MotherShip live file
`/etc/update-motd.d/10-prism` was not installed by a normal run of
`install-prism-net-assets.sh` unless another task or manual command copied it
separately.

Other repo references to MOTD:

- `docs/build-log.md` notes a 2026-04-18 verification pass after fixing MOTD
  installation to `/etc/update-motd.d/10-prism`.
- `docs/PRISM_115_MODEL_WORK_AUDIT_20260516.md` lists
  `/etc/update-motd.d/10-prism` as a live PRISM file that was intended to be
  checked on 192.168.14.115, but that audit said direct host-local SSH access
  was unavailable.

## PRISM Files Present On MotherShip

Expected or plausibly MotherShip-control-plane related:

```text
/etc/nginx/conf.d/115-prism-chain.conf
mode=644 owner=root:root size=334 mtime=2026-04-29 06:35:55 -0700

/etc/nginx/conf.d/fm05-prism-chain.conf
mode=644 owner=root:root size=297 mtime=2026-04-26 00:44:44 -0700

/etc/nginx/conf.d/prism-unknown-catchall.conf
mode=644 owner=root:root size=323 mtime=2026-05-01 14:51:05 -0700
```

These nginx configs serve iPXE chain responses from MotherShip. They do not
expose `/api/chat`, `/setup/state`, Ollama, Iris, or PRISM frontend/backend
routes. Hardware-specific path components were present but are intentionally
redacted here.

Older PRISM state/log directories:

```text
/var/lib/prism
type=directory mode=755 owner=root:root mtime=2026-04-28 10:34:17 -0700

/var/lib/prism/jobs
type=directory mode=755 owner=root:root mtime=2026-04-28 10:34:11 -0700

/var/lib/prism/setup-state.json
type=regular file mode=644 owner=root:root size=4041 mtime=2026-04-28 10:34:17 -0700

/var/log/prism-jobs
type=directory mode=755 owner=root:root mtime=2026-04-28 10:34:11 -0700
```

These are suspicious as live PRISM state on MotherShip unless MotherShip was
intentionally used for earlier setup-status/control-plane testing. They predate
the 2026-05-16 MOTD change and were not modified in the last 48 hours.

Suspicious/unwanted from the current incident:

```text
/etc/update-motd.d/10-prism
/etc/update-motd.d/10-prism.backup-20260516-color-fix
```

Absent requested live PRISM app paths:

```text
/etc/nginx/sites-available/prism-iris
/etc/nginx/sites-enabled/prism-iris
/var/www/prism-chat
/usr/local/bin/prism-setup-backend
/usr/local/lib/prism
/etc/prism
/opt/ollama
/usr/share/ollama
```

Other PRISM-named local binary:

```text
/usr/local/bin/prism-aider
mode=755 owner=root:root size=245 mtime=2026-04-15 08:15:29 -0700
```

This predates the incident and appears unrelated to the MOTD contamination.

## Recent MotherShip File Changes

Limited last-48-hour scan paths:

- `/etc/update-motd.d`
- `/etc/nginx`
- `/etc/systemd/system`
- `/usr/local/bin`
- `/usr/local/lib/prism`
- `/var/www`
- `/var/lib/prism`
- `/etc/prism`
- `/root/.ssh`
- `/etc/ssh`
- `/etc/hosts`
- `/etc/cron.d`
- `/var/spool/cron/crontabs`

Only recent matching changes found:

```text
2026-05-16 08:35:49 /etc/update-motd.d/10-prism.backup-20260516-color-fix
2026-05-16 08:35:49 /etc/update-motd.d/10-prism
2026-05-16 08:35:49 /etc/update-motd.d
```

No recent changes were found in the limited scan for nginx, systemd units,
`/usr/local/bin`, `/usr/local/lib/prism`, `/var/www`, `/var/lib/prism`,
`/etc/prism`, `/root/.ssh`, `/etc/ssh`, `/etc/hosts`, cron, or crontabs.

Additional spot-check metadata:

```text
/etc/hosts mtime=2026-03-30 17:35:57 -0700
/etc/ssh/sshd_config mtime=2026-03-26 07:44:54 -0700
/root/.ssh directory mtime=2026-05-15 08:40:40 -0700
```

## Packages

APT logs checked:

```text
/var/log/apt/history.log size=0 mtime=2026-05-01 00:25:39 -0700
/var/log/apt/term.log size=0 mtime=2026-05-01 00:25:39 -0700
```

No recent relevant package installation, upgrade, removal, or purge entries were
available in those logs.

## Services

Read-only systemd checks found:

```text
nginx.service enabled enabled
nginx.service loaded active running A high performance web server and a reverse proxy server
```

No PRISM, Iris, or Ollama unit files were listed by:

```text
systemctl list-unit-files | grep -Ei 'prism|iris|ollama|nginx'
```

No PRISM, Iris, or Ollama services were running according to:

```text
systemctl --type=service --state=running | grep -Ei 'prism|iris|ollama|nginx'
```

No matching PRISM, Iris, or Ollama systemd files were found under
`/etc/systemd/system`.

No matching PRISM, Iris, or Ollama cron files were found under `/etc/cron.d` or
`/var/spool/cron/crontabs`.

## Nginx

Read-only nginx checks found PRISM references only in these MotherShip control
plane files:

```text
/etc/nginx/conf.d/115-prism-chain.conf
/etc/nginx/conf.d/fm05-prism-chain.conf
/etc/nginx/conf.d/prism-unknown-catchall.conf
```

`nginx -T` with filtered output showed these configs listening on MotherShip IP
ports for iPXE chain/catchall behavior. The filtered output did not show
`/setup/state`, `/api/chat`, Ollama proxy routes, Iris app routes, or PRISM
frontend document roots.

`/etc/nginx/sites-available/prism-iris` and
`/etc/nginx/sites-enabled/prism-iris` are absent.

Conclusion: nginx does not appear to have received the live PRISM app routes
from the 2026-05-16 MOTD work. The existing PRISM-named nginx files appear to be
older MotherShip PXE/control-plane helpers.

## Shell History

Recent shell history was searched cautiously for relevant terms only. No command
was found showing a local copy/install of `10-prism` into
`/etc/update-motd.d`.

Relevant history entries found were status/read-only style checks and SSH checks
to other hosts for PRISM services. No secret values are reproduced here.

Conclusion: shell history did not identify the exact install command. The file
metadata, backup marker, task documentation, and git commit timing remain the
strongest evidence for the cause.

## Functional Impact

Observed functional impact on MotherShip:

- SSH login displays the PRISM MOTD banner and `http://prism.local` prompt.

Not observed:

- no live PRISM backend installed on MotherShip
- no PRISM frontend directory installed on MotherShip
- no Iris nginx site installed on MotherShip
- no PRISM/Iris/Ollama systemd services installed or running
- no recent package installs in apt history
- no recent changes in checked SSH config, hosts, cron, nginx, systemd, or
  application paths beyond `/etc/update-motd.d`

Assessment: this appears cosmetic from the 2026-05-16 incident, with older
PRISM-related MotherShip control-plane artifacts present separately.

## Recommended Cleanup Plan

Do not perform cleanup until approved.

Recommended cleanup for the incident:

1. Remove `/etc/update-motd.d/10-prism` from MotherShip.
2. Remove `/etc/update-motd.d/10-prism.backup-20260516-color-fix` from
   MotherShip after confirming the audit record is sufficient.
3. Open a fresh SSH session to MotherShip and verify the PRISM banner no longer
   appears.

Recommended separate review:

1. Decide whether `/var/lib/prism`, `/var/log/prism-jobs`, and
   `/usr/local/bin/prism-aider` are intentional MotherShip artifacts.
2. Decide whether the PRISM-named nginx iPXE chain configs should remain as
   MotherShip factory/PXE helpers. They appear control-plane related, not live
   app deployment.

## Prevention Rule

PRISM live deployment must require an explicit target host and must refuse to
deploy live files to MotherShip unless explicitly approved.

Implementation recommendations:

- Live deploy scripts should require `--target-host` or an equivalent explicit
  host argument.
- Scripts should detect MotherShip by hostname and IP and abort by default.
- A MotherShip override should require a loud flag such as
  `--allow-mothership-live-deploy`.
- PRISM image/rootfs installers should refuse `ROOTFS=/` unless explicitly
  approved.
- MOTD deployment should be split between image/rootfs installation and live-host
  deployment so a repo validation task cannot accidentally install to the local
  host.

