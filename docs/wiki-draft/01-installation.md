# 01 — Installation (DRAFT, uncommitted wiki)

> DRAFT — generated 2026-09-27 from repo files. Do not treat as published docs.
> Anything marked **VERIFY-ON-TARGET** could not be confirmed from the repo
> and must be checked on the real machine before this page goes live.

## What you are installing

LuicipherOS v0.1 is an **OS-config on top of Arch**, not a forked distro
(see `CONTEXT.md`, `docs/adr/0001-arch-vs-nixos.md`). You install a minimal
Arch base with archinstall, then this repo layers packages, dotfiles, and
Flatpaks on top. Target machine: **Ryzen 5 9600X + ASUS B650E-PLUS WIFI +
RX 7900 XT 20GB** (`README.md`, `TESTING.md`). Anything else is
best-effort until the compat matrix passes (target + AMD laptop + Intel
laptop + VM — see `docs/adr/0001-arch-vs-nixos.md`).

Out of scope for v0.1 (`README.md`): Nix home-manager, custom ISO as a
published artifact, NVIDIA hybrid, SecureBoot.

## Path A — VM smoke (proven 2026-09-26)

Proven configuration (`TESTING.md`): **QEMU/OVMF, Arch 2026.09.01 ISO,
4G RAM, 60G disk, UEFI**. All five checkpoints green: Hyprland loads,
SUPER+T Tabby, SUPER+Space Vicinae, SUPER+N swaync, Print region → Gradia.

```bash
./install/preflight.sh --vm        # expect PASS (GPU/ReBAR skipped)
# EDIT-ME: install/archinstall-desktop.json -> "device": "/dev/vda", hostname, timezone
cp install/archinstall-desktop.creds.example.json /tmp/creds.json
# fill /tmp/creds.json hashes: openssl passwd -6 'pw'
archinstall --config install/archinstall-desktop.json --creds /tmp/creds.json
# reboot into installed VM, clone repo, then:
./install/bootstrap.sh --preflight-mode=vm --no-flatpak
./scripts/sync.sh --prune --dry-run
```

PASS bar (`TESTING.md`): reboot reaches Hyprland (uwsm), terminal key
opens Tabby (see open question on SUPER+T vs SUPER+Return below),
SUPER+Space opens Vicinae (or fuzzel fallback), Quickshell bar + swaync
visible.

## Path B — target machine (Ryzen 9600X + RX 7900 XT)

Pre-install checklist is **manual** (Alza hardware checks, see
`install/preflight.sh` and `TESTING.md`):

- [ ] BIOS >= mid-2024 AGESA, EXPO enabled, Above-4G + ReBAR enabled
- [ ] 159mm cooler vs 160mm lid, 313mm GPU vs 330mm case, 2x separate 8-pin
- [ ] 2nd SSD planned; refurb report kept

```bash
./install/preflight.sh --target     # expect PASS; fix FAILs before proceeding
# EDIT-ME: device /dev/nvme0n1, hostname luicipheros, timezone Europe/Prague
archinstall --config install/archinstall-desktop.json --creds /tmp/creds.json
./install/bootstrap.sh --preflight-mode=target
./scripts/sync.sh                   # add-only reconcile
```

**VERIFY-ON-TARGET**: the target flow has not been run yet (`TESTING.md`:
"Remaining: target"). The VM smoke is the only proven path.

## The archinstall JSON (`install/archinstall-desktop.json`)

Base: btrfs + systemd-boot, NetworkManager, `amd-ucode`, Minimal profile,
AMD open-source gfx driver, `linux` kernel, pipewire audio. It ships with:

- `device`: `/dev/nvme0n1` — **EDIT-ME per disk** (`/dev/vda` in the VM).
  Full `lsblk` picker is issue #2 (`iso/airootfs/usr/local/bin/luicipheros-install`).
- btrfs partition: **55 GiB explicit** — fits the 60G VM; enlarge to
  (disk GiB minus 2) on target (see `_note` field in the JSON).
- ESP: 1024 MiB fat32 on `/boot` with `flags: ["boot", "esp"]`.
- `mirror_regions`: `{}` (empty) + `optional_repositories: ["multilib"]`.
- `"silent": false` — the TUI opens prefilled so a human reviews
  disk/users before writing (`AGENTS.md`).
- `custom_commands`: `systemctl enable NetworkManager`.
- zstd swap enabled.

Credentials: copy `install/archinstall-desktop.creds.example.json` to
`/tmp/creds.json`, fill password hashes via `openssl passwd -6
'YOUR_PASSWORD'`, **never commit** real secrets (see `_note` in the
example file). `luicipheros-install` on the ISO can generate this file
interactively instead (username + double-entered passwords → `chmod 600`).

Validate before use (`TESTING.md`):

```bash
bash -n scripts/*.sh install/*.sh && echo STATIC-OK
python3 -m json.tool install/archinstall-desktop.json > /dev/null && echo JSON-OK
python3 -m json.tool install/archinstall-desktop.creds.example.json > /dev/null && echo CREDS-EXAMPLE-OK
```

## `install/bootstrap.sh` — fresh Arch → LuicipherOS

Idempotent pipeline (`install/bootstrap.sh` header): **preflight →
pacman/AUR lists → stow dotfiles → flatpaks → enable services →
snapshot hint**. Safe to re-run; never prunes (removal lives in
`scripts/sync.sh --prune`).

```bash
./install/bootstrap.sh [--aur-helper yay|paru] [--no-flatpak] [--stow-only] [--preflight-mode any|target|vm]
```

What each stage does (from the script):

1. **Preflight** — strict: a `--target`/`--vm` failure aborts bootstrap.
2. **Packages (add-only)** — enables `multilib` idempotently if
   `/etc/pacman.conf` has it commented out (`sudo sed` + `sudo pacman
   -Sy`), then `scripts/ensure-packages.sh --aur-helper <helper>`.
3. **Stow** — links `hypr quickshell swaync tabby fuzzel vicinae uwsm
   xdg` from `dotfiles/` to `$HOME` (`stow -d dotfiles -t $HOME
   --restow <pkg>`). Prints hyprland version if present.
4. **Flatpaks** — skipped with `--no-flatpak` (e.g. offline/VM);
   otherwise `scripts/ensure-flatpaks.sh` (system + user).
5. **Services** — `sudo systemctl enable NetworkManager`, `bluetooth`,
   `power-profiles-daemon` (each best-effort), plus
   `xdg-user-dirs-update`. **No auto-sync units are installed**
   (manual-only sync is locked — `CONTEXT.md`).
6. **Snapshot hint** — prints (does not run):
   `sudo snapper -c root create --description 'luicipheros-bootstrap'`
   or `sudo timeshift --create --comments 'luicipheros-bootstrap'`.

Next step printed by the script: `./scripts/sync.sh`, then reboot →
Hyprland (uwsm). Verify with the `TESTING.md` matrix (ROCm: `rocminfo`,
`torch.cuda.is_available()`, Blender HIP, `ollama run llama3.2:3b`,
`hyprctl version >= 0.55`, `vicinae --version || vicinae toggle`,
`quickshell`, `gradia --help`, Print → Gradia, `tabby --version` + ssh).

**VERIFY-ON-TARGET**: `tabby -e nmtui` (fuzzel/swaync rely on the `-e`
exec flag) is explicitly marked VERIFY in `TESTING.md`.

## Path C — netinstall ISO (`iso/`, UNTESTED artifact)

`iso/README.md` status: **UNTESTED** — no `mkarchiso` in the dev
container; first build happens on the target-side Arch host. **Do not
publish under Releases until one VM boot of the built ISO reaches
archinstall.**

Design: small bootable ISO that fetches this repo over the network and
runs the install flow. Packages are NEVER baked in (rolling-release
correctness; a full offline image with Tabby + ROCm would be gigabytes
and stale within weeks). Layout:

- `iso/profiledef.sh` — archiso profile (releng-based, UEFI+BIOS boot).
- `iso/packages.x86_64` — live-env only: archinstall, git, network,
  disk tools (plus the hard-won fixes: `linux`, `mkinitcpio-archiso`,
  `systemd-sysvcompat`, `archlinux-keyring`, `reflector`, `openssh`,
  `iputils`, `pciutils`, `terminus-font` — see 04-troubleshooting).
- `iso/airootfs/usr/local/bin/luicipheros-install` — live entry point
  (preflight → repo → archinstall). Flow: clone/pull repo at
  `~/LuicipherOS` → preflight → device auto-select (`/dev/vda` with
  `--vm`, else `/dev/nvme0n1`, written to a `/tmp` copy so `git pull`
  stays clean) → interactive creds → live keyring rescue → confirm →
  `archinstall --config /tmp/luicipheros-archinstall.json --creds
  /tmp/creds.json --skip-wkd`. Bootstrap runs **after reboot in the
  installed system, never in the live env**.
- `iso/airootfs/etc/motd` — points at the installer.

Build (on Arch with mkarchiso, from `iso/README.md`):

```bash
sudo pacman -S --needed archiso
cp /etc/pacman.conf iso/pacman.conf   # host mirror pool, not shipped (rots)
# bootloader configs come from the LOCAL archiso (version-matched, not shipped):
cp -r /usr/share/archiso/configs/releng/syslinux iso/syslinux
cp -r /usr/share/archiso/configs/releng/efiboot iso/efiboot
sudo mkarchiso -v -w /tmp/luici-iso-tmp -o out/ iso/
# artifact: out/luicipheros-netinstall-*.iso — flash with dd/Etcher/Ventoy
```

Test: boot the artifact in the QEMU/OVMF VM (4G RAM, 60G disk, UEFI),
then `luicipheros-install --vm`. First boot that reaches `archinstall`
= ISO smoke PASS.

Live-session note: `/usr/local/bin/luicipheros-install` on the booted
ISO is frozen at build time; repo fixes reach it via the clone:

```bash
cd ~/LuicipherOS && git pull
cp iso/airootfs/usr/local/bin/luicipheros-install /usr/local/bin/luicipheros-install
luicipheros-install --vm
```
