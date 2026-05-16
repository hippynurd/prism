# PRISM MOTD Color Fix - 2026-05-16

## What was wrong

The PRISM MOTD color path was not safely deployed on the host. The live
`/etc/update-motd.d/10-prism` script was missing, and the repo source did not
handle plain-output environments such as `TERM=dumb` or `NO_COLOR=1`.

When MOTD output is rendered in a terminal that does not interpret ANSI escape
codes, color sequences can appear as visible escape text instead of colors.

## What changed

- Kept the repo source at `net/motd/10-prism`.
- Switched the script to `/bin/sh` and `printf`-only output.
- Emits ANSI color with `printf '\033[%sm' ...` only when color is allowed.
- Prints the same PRISM banner, tagline, and `http://prism.local` text without
  escape codes when `TERM=dumb` or `NO_COLOR` is set.
- Installed the validated script to `/etc/update-motd.d/10-prism` with mode
  `0755`.

No packages were installed, no services were restarted, no backend jobs were
triggered, and no network calls were added.

## Live backup

Backup path:

```sh
/etc/update-motd.d/10-prism.backup-20260516-color-fix
```

On this host, no previous `/etc/update-motd.d/10-prism` file existed, so the
backup path contains a short marker noting that there was no live file to copy.

## Test results

Syntax check:

```sh
sh -n /etc/update-motd.d/10-prism
```

Direct execution:

```sh
/etc/update-motd.d/10-prism
TERM=dumb /etc/update-motd.d/10-prism
NO_COLOR=1 /etc/update-motd.d/10-prism
```

Byte checks:

```sh
env -u NO_COLOR TERM=xterm-256color /etc/update-motd.d/10-prism
# normal: no literal "\033" text
# normal: ANSI ESC bytes found

TERM=dumb /etc/update-motd.d/10-prism
# no ANSI ESC bytes found

NO_COLOR=1 /etc/update-motd.d/10-prism
# no ANSI ESC bytes found
```

Visual summary: normal terminal mode renders the PRISM ASCII banner in red,
yellow, green, blue, and magenta segments. `TERM=dumb` and `NO_COLOR=1` render
the same text in plain monochrome with no escape sequences.

## Rollback

Use this command to restore the pre-fix live state from the backup path:

```sh
if head -n 1 /etc/update-motd.d/10-prism.backup-20260516-color-fix | grep -q '^#!'; then
  install -m 0755 /etc/update-motd.d/10-prism.backup-20260516-color-fix /etc/update-motd.d/10-prism
else
  rm -f /etc/update-motd.d/10-prism
fi
```
