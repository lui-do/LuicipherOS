# 02 — Configuration: desired lists + sync (DRAFT, uncommitted wiki)

> DRAFT — generated 2026-09-27 from repo files. Do not treat as published docs.
> Anything marked **VERIFY-ON-TARGET** could not be confirmed from the repo
> and must be checked on the real machine before this page goes live.

## The idea (from `README.md`, `CONTEXT.md`, `docs/adr/0001-arch-vs-nixos.md`)

Declarative apps **without NixOS**: text files declare intent, sync
realizes it. Editing a list declares what should be installed; running
sync makes it so. Decision locked in grill, rationale in ADR-0001:
Arch-native + Nix-style files, with break-prevention guardrails
(manual-only sync, protected packages, explicit-only prune + confirm +
`--dry-run`, tiny AUR surface, weekly `Syu` test + `last-known-good` tag,
Timeshift/Snapper snapshot before sync, separate `/home`).

Glossary (`CONTEXT.md`): **desired list** = source-of-truth files;
**sync (`luci sync`)** = idempotent reconciler in `scripts/sync.sh`;
**protected package** = base package never auto-removed; **extra** =
explicitly installed package/app not in desired + protected sets
(previewed before prune, never silently removed).

## The desired lists (`config/`)

| File | Scope | Contents (v0.1) |
|---|---|---|
| `config/packages` | pacman (Arch repos) | base/boot/firmware, networking, audio, Hyprland core, shell tools, fonts, AMD GPU stack, flatpak/distrobox helpers |
| `config/packages-arch` | AUR via yay/paru | `yay-bin`, `vicinae`, `tabby-bin` (tiny surface on purpose) |
| `config/flatpaks-system.list` | flatpak `--system` (sudo, shared) | Firefox, Blender, OBS Studio |
| `config/flatpaks-user.list` | flatpak `--user` (no sudo, personal) | VS Code, Obsidian, KeePassXC |
| `config/flatpaks.list` | **legacy compat, system scope** | old single list, still honored — migrate lines into the split lists |
| `config/protected-packages` | prune guardrail | kernel, firmware, drivers, compositor, networking, boot chain |

Format: one package per line, `#` = comment, no versions pinned in v0.1
(track Arch Extra). Flatpak lines: `<remote> <app-id> [branch]`
(default branch `stable`).

Actual v0.1 package highlights (see the files for the full lists):

- `config/packages`: `base base-devel linux linux-firmware
  linux-firmware-amdgpu amd-ucode btrfs-progs networkmanager iwd bluez
  bluez-utils blueman power-profiles-daemon brightnessctl powertop
  pipewire wireplumber pipewire-pulse pipewire-alsa pavucontrol
  playerctl hyprland hyprlock hypridle xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk uwsm quickshell fuzzel swaync wl-clipboard
  cliphist grim slurp gradia gnome-keyring yazi neovim git less stow
  curl wget unzip ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
  nwg-look mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
  xf86-video-amdgpu rocm-hip-runtime hip-runtime-amd vulkan-tools
  radeontop flatpak distrobox xdg-user-dirs polkit-gnome`.
  Replaced/removed (with in-file NOTEs): `waybar` → custom Quickshell
  shell; `swappy` → Gradia; `kitty` → AUR `tabby-bin`; `wlogout`,
  `hyprland-qtutils`, `systemd-boot-pacman-hook` gone from Sep 2026 repos.
- `config/packages-arch`: `yay-bin`, `vicinae`, `tabby-bin`
  (prebuilt over source-build `tabby`). Deferred to v0.2 (commented):
  `noctalia-shell`, `hyprpanel`, `matugen`, `awww`, `protonup-qt`.
- `config/protected-packages`: `base base-devel linux linux-firmware
  linux-firmware-amdgpu amd-ucode networkmanager iwd bluez pipewire
  wireplumber hyprland hyprlock hypridle xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk flatpak sudo git mkinitcpio efibootmgr
  btrfs-progs`. The boot-chain trio was added after the VM prune
  preview listed them as extras (removing them bricks boot).

Locked rule (ADR-0001): **Hyprland/lock/portals/drivers stay
pacman-owned** (PAM/SUID + GL traps: `/run/opengl-driver` + nixGL,
hyprlock/keyring must stay system). Never put them in Flatpak lists.

## `scripts/sync.sh` — the reconciler

```bash
./scripts/sync.sh                 # add-only (default): install missing only
./scripts/sync.sh --prune         # + remove extras (asks confirm unless --yes)
./scripts/sync.sh --prune --dry-run  # preview only, changes nothing
```

Behavior (from `scripts/sync.sh`):

1. **Add path (always runs unless `--dry-run`)**:
   `scripts/ensure-packages.sh` + `scripts/ensure-flatpaks.sh`, then
   `flatpak update -y --system`, `flatpak update -y --user`,
   `flatpak uninstall --unused -y --system/--user`. Deps (`pacman
   -Qqd`) are never touched; removal logic lives only in `--prune`.
2. **Prune path (opt-in only)**:
   - pacman extras = (`pacman -Qqe` explicitly installed) minus
     (desired + protected). Deps never touched.
   - flatpak extras per scope = (installed `--app`s) minus (desired
     app IDs from all three flatpak lists). System/user scopes prune
     **independently**.
   - Prints `pacman extras (N): …`, `flatpak system extras (N): …`,
     `flatpak user extras (N): …`. Nothing to prune → `nothing to
     prune`, exit 0.
   - `--dry-run` stops before removal. Otherwise asks `Remove above
     extras? [y/N]` unless `--yes`.
   - Removal: `sudo pacman -Rns --noconfirm <extras>`,
     `flatpak uninstall -y --system/--user <extras>`.

Locked for v0.1 (`CONTEXT.md`): **manual-only, no auto-sync on boot**.
Reboot does nothing by itself (`README.md`).

Contract tests: `tests/test_sync.sh` (mock pacman/flatpak/sudo +
fixture config; covers add-only, dry-run preview, protected guard,
scope split, removal commands, nothing-to-prune). **VERIFY-ON-TARGET**:
test count/contents evolve with the suite — run `./tests/test_sync.sh`
(exit 0 = all pass) rather than trusting any number quoted here.

## `scripts/ensure-packages.sh` and `scripts/ensure-flatpaks.sh`

- `ensure-packages.sh [--aur-helper yay|paru]` (default `yay`):
  `sudo pacman -S --needed --noconfirm $(config/packages)`, then AUR
  via the helper. Chicken-and-egg fix: if `yay` is missing it
  **bootstraps yay-bin once from the AUR directly** (`git clone
  https://aur.archlinux.org/yay-bin.git` + `makepkg -si --noconfirm`
  in a temp dir). No auto-bootstrap for `paru` — install it first
  (warning + skip AUR). Never removes anything.
- `ensure-flatpaks.sh`: iterates each list (`remote app [branch]`,
  comments/blanks skipped); `flatpak remote-add --if-not-exists` for
  flathub; installs only apps where `flatpak info <scope> <app>`
  fails. System list → `--system`, user list → `--user`, legacy
  `flatpaks.list` → `--system` with a migrate-away NOTE. Never removes
  anything.

## Flatpak scope split (locked: SPLIT)

- **System** (`config/flatpaks-system.list`, needs sudo): browsers,
  media, Blender, OBS — apps every user should have.
- **User** (`config/flatpaks-user.list`, no sudo): dev/personal apps —
  editors, notes, secrets — so the shared system stays lean.
- Legacy `config/flatpaks.list` = system scope (compat). Migrate its
  lines into the split lists.
- No Flatpak equivalent of `--from-file` (see flatpak#5186 per the
  in-file comment) — these lists + the script ARE the declarative layer.
- Vicinae note (`config/flatpaks-user.list` comment): no upstream
  Flatpak exists; use AUR `vicinae`.

## Day-to-day workflow

```bash
# add an app: edit the right list, then
./scripts/sync.sh
# remove an app: delete its line, then
./scripts/sync.sh --prune --dry-run   # preview first
./scripts/sync.sh --prune             # confirm, protected guard applies
```

Before first sync: take a snapshot (ADR-0001 break prevention):
`sudo snapper -c root create --description 'luicipheros-bootstrap'` or
`sudo timeshift --create --comments 'luicipheros-bootstrap'`
(printed by `install/bootstrap.sh`).
