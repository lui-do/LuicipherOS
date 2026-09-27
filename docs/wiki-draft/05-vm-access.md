# 05 — VM access: SSH servers + tunneling (DRAFT)

Why this page exists: VM text consoles have no clipboard. Every pastebin
roundtrip risks typos (we lost time to `https;//`). Get SSH working FIRST
when testing, then do everything else over it.

## Prereqs (both sides need openssh)

Host: `sudo pacman -S --needed --noconfirm openssh`
Guest: same command in the VM (our ISO live env carries it; the installed
system gets it only if you add it — see below).

## Recommended: reverse tunnel (no VM reboots, no XML)

Slirp (usermode) networking lets guests reach out but not be reached.
So the guest dials out and the host rides back:

```bash
# host (one time): own SSH server must run
sudo systemctl enable --now sshd

# guest: open the tunnel, LEAVE the session open
ssh -o StrictHostKeyChecking=no -R 2223:localhost:22 <host-user>@10.0.2.2

# host, new terminal: in
ssh -p 2223 <guest-user>@127.0.0.1
```

`10.0.2.2` is the slirp gateway = the host, from any usermode VM.

## Alternative: inbound forward (needs VM restart)

`qemu:commandline` with `-net user,hostfwd=tcp::2222-:22` sort of works
but adds a SECOND slirp stack beside libvirt's own — we observed TCP
connects with no SSH banner (forward lands nowhere). Prefer the reverse
tunnel; if you must do inbound, remove the hack afterwards.

## Faster next time: bake it in

- ISO live env already ships openssh (commit `3bf9ebd`).
- Installed system: add `openssh` to `config/packages` if you want every
  install SSH-ready, plus `systemctl enable sshd` in `install/bootstrap.sh`.
  (VERIFY-ON-TARGET: not yet decided whether every machine should run sshd
  by default — security posture question.)

## Diagnosing a silent hang

`ssh -p 2222 user@127.0.0.1` hangs with zero output (even `-v` silent) =
TCP accepted, endpoint dead. Check in order:

```bash
ss -tln | grep 2222                        # host: forward listening?
systemctl is-active sshd                   # guest: server up?
ss -tln | grep :22                         # guest: something on 22?
timeout 8 curl -v telnet://127.0.0.1:2222  # banner? SSH-2.0 = healthy path
```

Banner but no login = client/auth issue. No banner = forward or server.
