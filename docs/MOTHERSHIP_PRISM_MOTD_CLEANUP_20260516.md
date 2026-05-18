# MotherShip PRISM MOTD Cleanup - 2026-05-16

Cleanup was performed on MotherShip on 2026-05-18 after the contamination audit.

## What Was Moved

The following active MotherShip MOTD files were moved out of
`/etc/update-motd.d`:

```text
/etc/update-motd.d/10-prism
/etc/update-motd.d/10-prism.backup-20260516-color-fix
```

Backup directory:

```text
/root/mothership-motd-cleanup-20260516/
```

Resulting backup files:

```text
/root/mothership-motd-cleanup-20260516/10-prism
/root/mothership-motd-cleanup-20260516/10-prism.backup-20260516-color-fix
```

## Why This Was Wrong

MotherShip is the factory, PXE, and control box. It should not present itself as
the live PRISM dev server on SSH login.

The live PRISM dev server is 192.168.14.115. The PRISM MOTD text that told users
to open `http://prism.local` was therefore misleading on MotherShip.

## Verification

After the move, `/etc/update-motd.d` no longer contained a PRISM entry.

`run-parts /etc/update-motd.d` generated only the standard MotherShip Linux MOTD
line. The PRISM banner and `prism.local` prompt no longer appeared.

## Not Touched

Older MotherShip/factory artifacts were intentionally not changed:

```text
/var/lib/prism
/var/log/prism-jobs
/usr/local/bin/prism-aider
/etc/nginx/conf.d/*prism*
```

No nginx config was changed. No services were restarted. No packages were
installed. No SSH config, keys, passwords, backend, frontend, Ollama, systemd
units, or PRISM jobs were changed or triggered.

## Prevention Rule

PRISM live deployment must require an explicit target host and must refuse to
deploy live files to MotherShip unless MotherShip is explicitly approved as the
target.

