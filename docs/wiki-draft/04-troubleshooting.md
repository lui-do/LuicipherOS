# 04 — Troubleshooting: every field lesson (DRAFT, uncommitted wiki)

> DRAFT — generated 2026-09-27 from repo files + git history (`git log`,
> issue #1 trail). Do not treat as published docs. Fixes are stated
> exactly as the repo records them; anything marked **VERIFY-ON-TARGET**
> has no repo evidence and must be confirmed on the real machine.

## How to use this page

Each entry: symptom → repo-grounded fix → where it lives. Static
sanity first (no Arch needed, `TESTING.md`):

```bash
bash -n scripts/*.sh install/*.sh && echo STATIC-OK
python3 -m json.tool install/archinstall-desktop.json > /dev/null && echo JSON-OK
./scripts/sync.sh --prune --dry-run   # previews extras, changes nothing
```

## archinstall JSON strictness (AGENTS.md field notes, 2026.09.01 ISO)

The CURRENT archinstall parser is strict — older examples lie. Sources
of truth: guided/config reference (archinstall.archlinux.page), schema
(`archinstall/lib/models/device.py`), `man archinstall`. Each of these
was a failed install:

1. **`sector_size` must be an OBJECT, never `null`.** Symptom:
   `TypeError` in `SectorSize.parse_args` (`DiskLayoutConfiguration.parse_arg`
   crash). Fix: every `size`/`start` carries
   `{"sector_size": {"unit": "B", "value": 512}, …}` — see both
   partitions in `install/archinstall-desktop.json` (commit `83840b2`).
2. **No `Percent` unit, no fill-remaining-disk.** Symptom: config
   rejected. Fix: `unit` comes from the fixed `Unit` enum
   (B/kB/MB/GB/… + KiB/MiB/GiB/… + `sectors`); the btrfs partition has
   an **explicit 55 GiB** (fits the 60G VM; EDIT-ME to disk GiB minus 2
   on target — full `lsblk` helper is issue #2). Commit `d08840d`.
3. **ESP needs the explicit `esp` flag.** Symptom: installer aborts
   with "EFI system part ESP not found" — `boot` alone is NOT
   recognized (`is_esp` checks `PartitionFlag.ESP`, verified against
   `device.py`). Fix: `flags: ["boot", "esp"]` on the fat32 partition
   (commit `1c0d42b`).
4. **Keep `"silent": false` for first runs.** The TUI opens prefilled
   so a human reviews disk/users before writing. Automate unattended
   only once the JSON is proven on that archinstall version.

## Boot / firmware

- **Legacy BIOS boot.** Symptom: preflight `[FAIL] legacy BIOS boot`.
  The JSON expects UEFI + systemd-boot. Fix: boot the ISO/media in
  UEFI mode. VM smoke uses **QEMU/OVMF** (`TESTING.md`, `iso/README.md`);
  `install/preflight.sh` fails fast on non-EFI (`/sys/firmware/efi`
  missing). **VERIFY-ON-TARGET**: exact OVMF firmware path / libvirt
  XML snippet is not recorded in the repo.
- **Missing amdgpu firmware.** Preflight warns if no
  `navi31*` firmware is on the ISO (`/usr/share` or `/usr/lib`
  firmware paths); the fresh install pulls `linux-firmware` +
  `linux-firmware-amdgpu` (`config/packages`, `install/preflight.sh`).
- **ReBAR.** Preflight checks `/sys/bus/pci/devices/*/resizable_bar`;
  if absent it warns: enable Above-4G Decoding + ReBAR (ASUS
  B650E-PLUS WIFI), EXPO, mid-2024+ AGESA BIOS. Skipped in `--vm` mode.

## Package-list breakage (VM smoke Sep 2026, commit `0c2e228`)

- **Repo-dead packages.** Symptom: archinstall/bootstrap fails on
  unknown packages. Fix: dropped `systemd-boot-pacman-hook`
  (kernel-install handles entries; run `bootctl update` after systemd
  upgrades), `hyprland-qtutils` (merged into `hyprland`), `wlogout`
  (session menu moves into the Quickshell shell in v0.2;
  power/reboot stay in the swaync buttons-grid; SUPER+SHIFT+Q
  unbound in `lua/binds.lua`). All recorded as NOTEs in
  `config/packages`.
- **multilib.** Symptom: `lib32-*` drivers unresolvable. Fix: JSON
  `optional_repositories: ["multilib"]` + idempotent enable in
  `install/bootstrap.sh` (uncomments `[multilib]` in
  `/etc/pacman.conf`, `pacman -Sy`). Verified via `pacman -Ss` on VM
  smoke.
- **Boot chain nearly pruned (commit `2704095`).** Symptom: VM prune
  preview listed `mkinitcpio efibootmgr btrfs-progs` as extras.
  Fix: added to `config/protected-packages` — removing them bricks boot.

## AUR helper chicken-and-egg (commit `2704095`)

Symptom: fresh system has no `yay`, so ALL of AUR (incl.
`vicinae`, `tabby-bin`) was skipped. Fix in
`scripts/ensure-packages.sh`: when helper is `yay` and missing,
one-time `git clone https://aur.archlinux.org/yay-bin.git` +
`makepkg -si --noconfirm` in a temp dir. No auto-bootstrap for
`paru` — install it first. Helper selectable:
`./install/bootstrap.sh --aur-helper yay|paru`.

## Desktop config crashes

- **Shipped Tabby config killed first run (commit `82e146b`).**
  Symptom: null `appearance` theme crash. Cause: even a comments-only
  `config.yaml` poisoned Tabby's theme resolution. Fix: ship NO config
  (Vicinae pattern — `dotfiles/tabby/.config/tabby/README` only,
  vanilla defaults win). Verified: SUPER+T opens after moving the file
  away. Companion fix: added `gnome-keyring` (Tabby SSH password store).
- **`dwindle:pseudotile` unknown key (commit `6a5d6cd`).** Symptom: VM
  smoke reported `unknown config key dwindle.pseudotile`. Cause: key
  removed upstream (verified against `ConfigValues.cpp`). Fix:
  removed; `lua/look.lua` keeps `preserve_split = true` for the
  sticky-split behavior.
- **Terminal key moved (commit `e2f44ec`).** Terminal is SUPER+T, not
  Return. See 03-desktop open question: `install/bootstrap.sh` echo
  and `TESTING.md` §1 still mention SUPER+Return in places.

## Live env / netinstall ISO lessons (`iso/`, commit trail)

- **Stale all-commented mirrorlist → `reflector`.** Symptom: pacman
  "no servers configured" in the live env. Fix: `reflector` in
  `iso/packages.x86_64` (+ `pciutils` restore — preflight needs
  `lspci`); enable `reflector.service` on live boot (official-ISO
  behavior). Host `pacman.conf` is deliberately NOT shipped (rots) —
  copy it at build time (`iso/README.md`).
- **Keyring rescue.** Symptom: fresh live boots start with NO (or
  broken) keyring; every pacman/archinstall run dies with keyring
  errors. Fixes: `archlinux-keyring` in live packages (provides the
  `wkd-sync` timer+service archinstall waits on — without it the
  install hangs forever at keyring sync), plus `ensure_keyring()` in
  `luicipheros-install` (rebuild via `pacman-key --init` +
  `--populate archlinux` unless ≥3 master keys found). **Note on
  `SigLevel = Never`: VERIFY-ON-TARGET** — no `SigLevel` setting
  exists anywhere in this repo; do not present it as a LuicipherOS
  fix. If a keyring rescue needs signature-level overrides, propose
  and test the exact `pacman.conf` stanza on target first.
- **`wkd-sync --skip-wkd`.** The wkd-sync wait hangs in minimal live
  envs without the timer unit, and crawls through slirp even with it
  (`luicipheros-install` comment). `luicipheros-install` passes
  `archinstall … --skip-wkd` by default; ISO keys are build-fresh.
- **No-network live env.** Preflight's network check has
  ping→curl→`/dev/tcp` fallbacks (the live ISO has no `ping` until
  `iputils` was added to live packages), and `NetworkManager` is
  enabled in the live env (no net = no netinstall).
- **ISO boot failures (each a commit):** `linux` kernel in live
  packages (ISO boot images are built from it); `mkinitcpio-archiso`
  + shipped `archiso.conf` HOOKS (without them: emergency mode,
  `gpt-auto-root` timeout); `systemd-sysvcompat` (provides
  `/sbin/init`; without it root mounts then bails); root autologin
  drop-in on tty1 (else the ISO stops at a login prompt); modern
  `bootmodes` (`bios.syslinux` + `uefi.systemd-boot`) with
  version-matched `syslinux`/`efiboot` copied from the local archiso
  at build time; `file_permissions` only for shipped files.
- **Frozen live script.** `/usr/local/bin/luicipheros-install` on a
  booted ISO is frozen at build time — repo fixes reach it via
  `git pull` + copy back (see 01-installation).

## Requested topics with NO repo evidence (do not publish as fact)

- **sudo timestamp keep-alive** (e.g. `sudo -v` loop during long
  runs): **VERIFY-ON-TARGET** — no such loop, helper, or systemd
  unit exists in `install/`, `scripts/`, or `iso/airootfs/`. Long
  `bootstrap`/`sync` runs may hit timestamp expiry; the fix (if any)
  must be designed and tested, not documented from memory.
- **slirp DNS quirks** (QEMU user-networking name resolution):
  **VERIFY-ON-TARGET** — the repo mentions slirp exactly once
  (wkd-sync slowness, above) plus `openssh` for hostfwd access. No
  DNS workaround (resolv.conf, `-dns`, host Resolver changes) is
  recorded. If VM networking misbehaves, capture symptoms first.
- **Mirror typos** (wrong Server URLs / regions):
  **VERIFY-ON-TARGET** — `mirror_regions` ships empty `{}` and no
  typo incident is recorded. Candidate preventive doc (unverified):
  keep regions empty for smoke, set them in the EDIT-ME pass on
  target — confirm before publishing.
- **Exact QEMU/OVMF invocation** (drive, firmware, hostfwd flags):
  **VERIFY-ON-TARGET** — the repo records "QEMU/OVMF, 4G RAM, 60G
  disk, UEFI" only. No command line is stored; do not invent one.
