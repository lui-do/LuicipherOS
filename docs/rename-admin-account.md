# Renaming the admin account (`luci` → `lui`)

Status: **NOT DONE — decision pending.** No rename has been performed.

## Why this is being considered

The CLI was renamed to `lui`. The admin account is still `luci`, so the machine has two names one
letter apart, and they are easy to confuse in a terminal. Renaming the account would remove that.

This is **cosmetic**. It fixes no functional problem, and it does **not** fix the stale-clone
hazard (see the shared-tree plan), which is architectural.

## Why it is safer than most account renames

`usermod -l` changes the **login name only; the UID does not change.** File ownership on Linux is by
UID, so nothing on disk changes owner. The classic rename damage — orphaned files in `/var`,
`/tmp`, `/srv` — does not apply here.

What still needs attention is anything that stores the **path** or the **name as a string**.

## The real blocker

`usermod` refuses to rename a user that has running processes, and `luci` is the **only** sudoer on
this machine. That creates a chicken-and-egg:

- Renaming `luci` requires root.
- Root is obtained by being `luci`.
- But `luci` must not be logged in while being renamed.

`sudo -i` does not cleanly escape this: killing `luci`'s processes takes the invoking terminal's
session with it. The failure mode if this goes wrong is **losing sudo access entirely**.

### Ways through, safest first

1. **Temporary second admin.** Create `tmpadmin`, add it to `wheel`, set a password, log in as it,
   perform the rename, verify, then delete it. Recommended.
2. **Root TTY.** Only if `root` has a password set and console login is permitted. Status on this
   machine: **UNCONFIRMED**.
3. **Rescue/live boot.** Bulletproof, heavy.

## Procedure (once root access independent of `luci` is available)

```bash
# 0. Make sure nothing is logged in as luci, and no processes remain:
#      pgrep -u luci
# 1. Rename the primary group (GID unchanged).
sudo groupmod -n lui luci
# 2. Rename the login and move the home directory.
sudo usermod -l lui -d /home/lui -m luci
# 3. Verify.
id lui
getent passwd lui
ls -ld /home/lui
```

`/home/lui` must not already exist. The LUKS passphrase is unaffected (different layer).

## Checklist after the rename

- [ ] `sudo` still works for the renamed account (`sudo -v`).
- [ ] Graphical login works; greetd/TUIgreet shows the new name.
- [ ] The keyring still unlocks (keyrings are encrypted with the password, not the name).
- [ ] SSH keys and `~/.ssh/config` still work.
- [ ] Flatpak user installs still run (`flatpak list --user`).
- [ ] Search for stale absolute paths:
      `grep -rl '/home/luci' /home/lui 2>/dev/null`
- [ ] No systemd user units reference the old name (`systemctl --user list-units`).
- [ ] The clone moves to `/home/lui/LuicipherOS`; `lui root` resolves there and it is **still
      stale** until pulled. The rename does not update it.

## Repo references to update if the rename happens

- `install/archinstall-desktop.creds.example.json` → `"username": "luci"`
- `docs/target-bringup-runbook.md` → "log in as luci"
- `docs/inventory-2026-11-02.md` → the `luci` flatpak scope rows
- `config/flatpaks-user.list` → "User `luci` also has personal copies"
- `AGENTS.md` → the guardrail line "`luci` is the admin account"

## Recommendation

**Do not rename the account now.** It is cosmetic, the lockout risk is real, and the shared-tree
work makes the account name irrelevant. If it is done later, do it deliberately with a temporary
second admin, on a day when a lockout would not be disruptive.

## Related note: `work` and sudo

`work` **is** in the `wheel` group (`wheel:x:998:luci,work`), so it is not blocked by group
membership. It cannot `sudo` because it has no usable password. If that is deliberate hardening,
leave it. If not, `sudo passwd work` (as `luci`) fixes it.
