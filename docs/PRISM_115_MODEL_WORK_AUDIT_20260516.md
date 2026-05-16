# PRISM 192.168.14.115 Model Work Audit - 2026-05-16

## Scope

Target audited: `192.168.14.115` (`prism.local`).

This was a containment audit for possible tiny Iris model work on the stable
PRISM development/server target.

Rules followed:

- No packages installed.
- No files removed.
- No services restarted or stopped.
- No backend install jobs triggered.
- No model pulls, deletes, or tests run.
- No secrets, tokens, cookies, private keys, raw MACs, disk serials, or API keys
  printed into this report.

## Access result

Host-local SSH access was not available from the audit shell.

Host-local audit incomplete because SSH access is unavailable.

SSH diagnosis on 2026-05-16:

| Check | Command | Username | Result |
| --- | --- | --- | --- |
| Port reachability | `nc -vz 192.168.14.115 22 || true` | n/a | Port 22 reachable: `(UNKNOWN) [192.168.14.115] 22 (ssh) open`; reverse lookup failed but TCP connected |
| SSH probe | `ssh -o BatchMode=yes -o ConnectTimeout=5 root@192.168.14.115 true` | `root` | Permission denied: `Permission denied (publickey,password).`; exit `255` |
| SSH probe | `ssh -o BatchMode=yes -o ConnectTimeout=5 user@192.168.14.115 true` | `user` | Permission denied: `Permission denied (publickey,password).`; exit `255` |

Classification:

- Network issue: no.
- Timeout: no.
- Host key issue: no.
- Permission denied: yes.
- Password prompt attempted: no, `BatchMode=yes` was used.
- Brute-force or repeated password guessing: no.

Attempts using non-interactive SSH with available keys failed for:

- `root@192.168.14.115`
- `prism@192.168.14.115`
- `ubuntu@192.168.14.115`
- `debian@192.168.14.115`
- `mothership@192.168.14.115`

Result:

```text
Permission denied
```

Because of this, the following host-local checks could not be completed in this
pass:

- Hostname from the host shell.
- Uptime from the host shell.
- Host date/time from the host shell.
- `df -h`.
- `free -h`.
- `nvidia-smi`.
- Live process table.
- Host-local PRISM repo status.
- Live file checksums and mtimes.
- Direct `ollama list` output and model manifest timestamps.
- Local tiny-model artifact search.
- Recent apt history.
- Recent systemd unit file changes.
- Recent `/etc` changes.

The network target is reachable by ICMP, and `192.168.14.115` resolves as
`prism.local` / `prism` from the audit shell.

## Endpoint Security Checks

The public PRISM safety endpoints were checked from the network side.

| Check | Result |
| --- | --- |
| `GET /setup/state` | `200 OK`, JSON |
| `GET /hardware` | `403 Forbidden` |
| `GET /setup/hardware` | `403 Forbidden` |
| `GET /setup/jobs` | `403 Forbidden` |
| `POST /setup/jobs/install_vaultwarden` | `403 Forbidden` |
| `POST /setup/check-prism-status` | `200 OK`, JSON |

Sanitization checks:

- `/setup/state` returned JSON with public setup state keys only.
- No raw MAC address values were detected.
- No private key markers were detected.
- `nics[*].mac` and `extra_disks[*].serial` fields exist, but values were not
  printed in this report. The public state privacy check below reports serial
  fields redacted.
- `/setup/check-prism-status` returned JSON with no raw MAC address values and
  no private key markers.

## Read-Only PRISM Status Job

The approved read-only backend status endpoint succeeded:

```text
status: succeeded
exit_code: 0
read_only: true
summary: Read-only PRISM status snapshot collected by approved backend job.
rollback_hint: No changes made; read-only job.
changed_files_count: 0
changed_services_count: 0
stdout_bytes: 0
stderr_bytes: 0
```

Reported check groups:

- `markers`
- `models`
- `nginx`
- `ollama`
- `ports`
- `prism_setup_backend`
- `public_api`
- `setup_state`

Reported service states:

- nginx: active
- ollama: active
- prism setup backend: active

Reported public API state:

- `/setup/state`: sanitized
- `/setup/jobs`: blocked by nginx

Reported setup-state privacy:

- raw MAC addresses present: false
- serial fields redacted: true

## Ollama / Model Findings

The read-only PRISM status endpoint reported Ollama reachable with two models:

- `llama3.1:8b`
- `qwen2.5:1.5b`

`llama3.1:8b` still exists.

`qwen2.5:1.5b` is a likely tiny-model-work artifact or dependency, but this
audit could not determine when it was added because direct host-local model
manifest timestamps were unavailable without SSH access.

No model tests were run.
No models were pulled.
No models were deleted.

## Live PRISM Files

The following requested live files could not be checked directly because
host-local SSH access was unavailable:

- `/var/www/prism-chat/index.html`
- `/usr/local/bin/prism-setup-backend`
- `/usr/local/lib/prism/setup-jobs/check_prism_status.sh`
- `/etc/nginx/sites-available/prism-iris`
- `/etc/update-motd.d/10-prism`

However, the read-only backend status endpoint reported:

```text
changed_files_count: 0
changed_services_count: 0
```

That is a positive health signal, but it is not a substitute for direct
checksum/mtime comparison once shell access is available.

## Heavy Processes

Could not be verified directly because host-local SSH access was unavailable.

The read-only backend status endpoint reports:

- nginx active
- ollama active
- prism setup backend active
- ports available

It did not expose a host process table, so this audit cannot confirm whether
`codex`, training, bakeoff, `python`, `node`, `llama`, `qwen`, `model`, or
other heavy model-work processes are still running.

## Disk / Memory / GPU

Could not be verified directly because host-local SSH access was unavailable.

Disk-space risk is therefore unknown from this pass. This should be checked
before cleanup or rollback decisions:

```sh
df -h
free -h
command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi
```

## What Changed

Confirmed from network/read-only backend data:

- Endpoint security still behaves as expected.
- PRISM read-only status job succeeds.
- No changed files or changed services were reported by the read-only status
  job.
- Ollama has `llama3.1:8b`.
- Ollama also has `qwen2.5:1.5b`.

Not confirmed in this pass:

- Whether `qwen2.5:1.5b` was newly added by the other session.
- Whether tiny-model work artifacts exist under `/tmp`, `/root`,
  `/root/mothership-setup`, `/vault/pve-media/projects/prism/net/models`,
  `/var/lib/prism`, or `/var/log`.
- Whether apt, systemd, nginx, backend, frontend, MOTD, or repo files were
  touched at the host filesystem level.
- Whether any heavy processes are still running.
- Whether disk space is healthy.

## Risk Level

Medium.

Reason: PRISM's public endpoint security and read-only backend status look
healthy, and no changed files/services were reported by the approved status job.
The risk remains medium because host-local access was unavailable, so disk,
process, package, filesystem timestamp, and model-manifest checks are still
incomplete.

## PRISM Health

PRISM appears healthy from the public/read-only backend surface:

- Safety endpoints pass.
- Read-only status endpoint passes.
- nginx, Ollama, and the setup backend are reported active.
- `llama3.1:8b` still exists.

Final health answer for this pass: yes from the network/read-only surface, but
host-local health is not fully audited.

## Rollback Recommendation

No rollback is recommended from the evidence available in this pass.

Reason:

- Endpoint protections still pass.
- Read-only backend status succeeds.
- The approved status endpoint reports zero changed files and zero changed
  services.

Rollback should only be considered if the pending host-local audit finds touched
live files, service changes, repo drift, package changes, or damaging model-work
artifacts.

## Cleanup Recommendation

Cleanup is recommended, but not yet performed.

Recommended cleanup target candidates:

- Verify whether `qwen2.5:1.5b` was intentionally installed on 115.
- If not needed, remove it only after approval.
- Search for and remove tiny-model bakeoff/test artifacts only after evidence is
  captured and approval is given.

## Exact Cleanup Plan - Do Not Run Yet

After host-local shell access is available, run these read-only checks first:

```sh
hostname
uptime
date -Is
df -h
free -h
command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi
ps -eo pid,user,etimes,pcpu,pmem,comm,args --sort=-pcpu
```

Check repo and live files:

```sh
for d in /vault/pve-media/projects/prism /root/prism /opt/prism /srv/prism; do
  [ -d "$d/.git" ] && git -C "$d" status --short && git -C "$d" rev-parse HEAD && git -C "$d" log --oneline -5
done

stat -c '%n %s %y' \
  /var/www/prism-chat/index.html \
  /usr/local/bin/prism-setup-backend \
  /usr/local/lib/prism/setup-jobs/check_prism_status.sh \
  /etc/nginx/sites-available/prism-iris \
  /etc/update-motd.d/10-prism
sha256sum \
  /var/www/prism-chat/index.html \
  /usr/local/bin/prism-setup-backend \
  /usr/local/lib/prism/setup-jobs/check_prism_status.sh \
  /etc/nginx/sites-available/prism-iris \
  /etc/update-motd.d/10-prism
```

Check Ollama without running models:

```sh
ollama list
find /usr/share/ollama/.ollama/models/manifests /root/.ollama/models/manifests \
  -type f -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null
```

Check likely small artifacts without reading model blobs:

```sh
find /tmp /root /root/mothership-setup /vault/pve-media/projects/prism/net/models /var/lib/prism /var/log \
  -xdev -maxdepth 5 -type f -size -20M -mtime -7 \
  \( -iname '*IrisCore*' -o -iname '*Modelfile*' -o -iname '*iris-core*' -o \
     -iname '*iris-code*' -o -iname '*qwen*' -o -iname '*llama3.2*' -o \
     -iname '*model*bakeoff*' -o -iname '*test-iris-models*' \) \
  -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null
```

Only after review and explicit approval, possible cleanup commands:

```sh
# If qwen2.5:1.5b is confirmed unwanted:
ollama rm qwen2.5:1.5b

# If specific tiny-model artifacts are confirmed unwanted:
rm -- <approved-file-or-directory>
```

No cleanup was performed during this audit.
