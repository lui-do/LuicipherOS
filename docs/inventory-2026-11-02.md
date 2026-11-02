# Desktop inventory, 2026-11-02

Read-only snapshot of what is installed on the target desktop and how `luci sync` sees it.
Nothing was removed or installed to produce it. Repo state: commit `162fe9c`.

## Method

- Pacman and AUR data: queried as user `work` (the package database is system-wide).
- Flatpaks: `flatpak list` as `work` (system and user scope) and as `luci` (user scope).
- Preview: `./scripts/sync.sh --prune --dry-run` (stops before any removal).
- Install dates are pacman's latest install/upgrade time, not the original install.

## Pacman packages installed outside the lists (21)

| Package | Role | Decision |
|---|---|---|
| linux-lts, linux-lts-headers | recovery kernel (arch-lts entry) | declared; linux-lts protected |
| snapper, snap-pac | root snapshots | declared |
| dosfstools | ESP check (`fsck.fat`) | declared |
| firewalld | firewall | declared (config not reviewed) |
| wpa_supplicant | Wi-Fi (needed by networkmanager) | declared |
| zram-generator | zram swap | declared |
| podman | containers | declared |
| docker-compose | compose client (Docker engine not confirmed) | declared |
| python-pip, socat | tools | declared |
| gst-plugin-pipewire, pipewire-jack | audio plumbing | declared |
| libpulse | needed by helium-browser-bin, pavucontrol and others | declared |
| 7zip, rsync, vim | tools | declared |
| udiskie, udisks2 | removable-disk automount | declared |
| yay-bin-debug | debug symbols for yay-bin | undecided, left installed |

Declared means added to `config/packages` (20 packages). The dry-run listed exactly these 21.

## AUR / foreign packages

helium-browser-bin, tabby-bin, vicinae-bin, yay-bin (all in `config/packages-arch`) and
yay-bin-debug (undecided).

## Flatpaks

| App | system | `work` user | `luci` user |
|---|---|---|---|
| Blender, OBS Studio | yes | no | no |
| VS Code, Obsidian, KeePassXC | yes | no | yes |

Policy (2026-11-02): all five are declared system-wide in `config/flatpaks-system.list`;
`config/flatpaks-user.list` is empty. The personal copies under `luci` are left untouched
(decision pending). The legacy `config/flatpaks.list` still lists the same five as system scope.

## Installed outside pacman and Flatpak (not touched by sync)

Install source and versions are UNCONFIRMED for everything below.

- `~/.cargo/bin`: `rustup` and toolchain shims (cargo, rustc, rust-analyzer, and so on).
- `~/.local/bin`: `mise`, `slk`, `vi-sql`, `slack-mcp`, Python entry points (`pip`, `pip3`,
  `pip3.12`, `pymupdf`) and ODF utility scripts (`odf*`, `csv2ods`, `mailodf`, `xml2odf`).
- `slack-mcp` is an owner-only wrapper script. It was not read. It may hold credentials: never
  commit it.
- `/opt`: `helium-browser-bin` and `Tabby` (AUR packages), `rocm` (pacman ownership not checked).
- `/usr/local/bin`: empty.

## How sync treats this (read from the scripts)

- Prune looks only at explicitly installed pacman packages and Flatpak apps for the account that
  runs it. Hand-installed tools above are never removed, and are never reinstalled on a new machine.
- The desired Flatpak IDs are merged across all lists, so prune does not notice a scope mismatch.
  `ensure-flatpaks.sh` checks each scope separately: with VS Code, Obsidian and KeePassXC in the
  old user list it would have installed a second, per-user copy.

## Sync audit items (not done; each needs a test before the first real run)

1. `ensure-packages.sh` runs `sudo pacman -S --needed --noconfirm` without `-y` or `-u`. A stale
   database risks a partial upgrade (the 2026-10-31 qemu failure was this class). Run a full
   `pacman -Syu` first. Account `work` has no sudo.
2. Prune removes with `pacman -Rns --noconfirm`; `-s` can also remove dependencies that become
   unneeded. Review the removal list before any prune.
3. Plain `sync.sh` also runs `flatpak update -y` and `flatpak uninstall --unused -y` for both scopes.
4. Prune only sees the invoking account's `--user` scope.
5. The legacy `config/flatpaks.list` duplicates the system list and can be retired later.

## Regenerate

```bash
cd ~/LuicipherOS
./scripts/sync.sh --prune --dry-run
comm -23 <(pacman -Qqe | sort -u) \
  <(grep -vhE '^\s*(#|$)' config/packages config/packages-arch config/protected-packages | sort -u)
flatpak list --system --app --columns=application,origin,installation
flatpak list --user --app --columns=application,origin,installation
```
