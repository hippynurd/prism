# PRISM Dev SSH Access - 2026-05-17

This documents the dev-only SSH key path from MotherShip to the current live
PRISM dev server at `192.168.14.115`.

## Why This Exists

During active development, MotherShip Codex needs a reliable way to SSH/SCP repo
changes to the 115 PRISM dev server without password prompts. This is for
bootstrap and development deployment only.

`192.168.14.115` is the current dev PRISM server. It is not a production
hardcoded IP.

## Dev-Only Warning

This key must not ship in production images.

This access must be removed before image-clean/finalization.

Do not use this key as a production credential, do not commit the private key,
and do not bake it into PRISM artifacts.

## MotherShip Key Path

Private key on MotherShip:

```text
/root/.ssh/prism_dev_ed25519
```

Public key on MotherShip:

```text
/root/.ssh/prism_dev_ed25519.pub
```

Key comment:

```text
mothership-prism-dev-deploy-key
```

## Intended SSH Alias

Alias:

```text
prism-115
```

Intended `/root/.ssh/config` stanza after key login works:

```sshconfig
Host prism-115
    HostName 192.168.14.115
    User root
    IdentityFile /root/.ssh/prism_dev_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
```

## Test Command

Direct key test:

```sh
ssh -i /root/.ssh/prism_dev_ed25519 -o BatchMode=yes root@192.168.14.115 true
```

Alias test after the config stanza exists:

```sh
ssh -o BatchMode=yes prism-115 true
```

## Current Status

The MotherShip key was created locally.

The public key was not installed on 115 from this session because
`ssh-copy-id` required an interactive password prompt and the password must not
be captured through chat or tooling logs.

Current direct key test result:

```text
key login works: no
```

Current alias test result:

```text
alias works: no
```

The `prism-115` alias should be added only after the public key is installed and
the direct key test succeeds.

## Bootstrap Install Procedure

Run from MotherShip in an interactive terminal where the human can type the
bootstrap password directly into the SSH prompt:

```sh
ssh-copy-id -i /root/.ssh/prism_dev_ed25519.pub root@192.168.14.115
```

Do not paste the bootstrap password into chat, logs, docs, shell history notes,
or commits.

After `ssh-copy-id` succeeds, verify:

```sh
ssh -i /root/.ssh/prism_dev_ed25519 -o BatchMode=yes root@192.168.14.115 true
```

Then add the `prism-115` SSH config stanza and verify:

```sh
ssh -o BatchMode=yes prism-115 true
```

## Removal Before Image-Clean/Finalization

Before image-clean/finalization:

1. Remove the public key from `/root/.ssh/authorized_keys` on 115.
2. Remove or archive `/root/.ssh/prism_dev_ed25519` on MotherShip.
3. Remove `/root/.ssh/prism_dev_ed25519.pub` on MotherShip if no longer needed.
4. Remove the `Host prism-115` stanza from `/root/.ssh/config` if desired.

Do not ship this key in production images.

