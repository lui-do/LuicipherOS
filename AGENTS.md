# Project Overview

LuicipherOS is an Arch-based, Hyprland-first, keyboard-driven OS configuration: dotfiles, an
`archinstall` profile, a bootstrap flow and declarative package lists, reconciled by `luci sync`.
It is not a forked distro in v0.1. Elevator pitch: NixOS-style declarative apps (edit a list,
sync realizes it) on plain Arch, with a SUPER-key desktop (Hyprland native Lua, Vicinae,
Quickshell, Tabby, Gradia). v0.1 is tuned for one target machine (Ryzen 5 9600X + ASUS TUF GAMING
B650E-PLUS WIFI + RX 7900 XT 20GB) and tested in a QEMU/OVMF VM.

Current status (from `TESTING.md` and git history, last commit 2026-10-06):

- VM smoke and ISO-loop PASS (2026-09-26, 2026-09-28; re-verified Oct 2026).
- Target-machine bring-up in progress; open DMUB cold-boot issue on the 7900 XT
  (see `docs/dmub-coldboot-casefile.md`).
- Compatibility claim stays limited until target + AMD laptop + Intel laptop + VM all pass
  (ADR-0001).

## Operational Metadata

- Unified Agent Prompts version: `v1.0`
- Prompt source: "Project Documentation & Maintenance" prompt (AGENTS.md + CONTINUITY.md).
- Documentation reference: this file is the canonical blueprint; operational history lives in
  `.agent/CONTINUITY.md`; vocabulary lives in `CONTEXT.md`.
- Project version: v0.1 (draft), per `README.md`.
- Last documentation sync: 2026-10-31 (against commit `d53f205`).
- Issue tracker: GitHub Issues via `gh` CLI (`docs/agents/issue-tracker.md`). Main tracking
  issue: #1.
- Triage labels: five canonical roles mapped 1:1 to label strings
  (`docs/agents/triage-labels.md`).
- Domain docs: single-context layout, `CONTEXT.md` + `docs/adr/` (`docs/agents/domain.md`).

## Repository Structure

```
LuicipherOS/
├── .agent/CONTINUITY.md   # operational log (this documentation task)
├── .agents/skills/        # agent skills (pinned by skills-lock.json)
├── AGENTS.md              # this blueprint
├── CONTEXT.md             # glossary + locked decisions
├── README.md              # user-facing overview, install, roadmap
├── TESTING.md             # test matrix and smoke results
├── LICENSE                # MIT
├── skills-lock.json       # lockfile for agent skills
├── config/                # desired lists: packages, AUR, flatpaks, protected packages
├── desktop/               # target-machine hardware report
├── docs/                  # ADRs, agent docs, troubleshooting, runbooks, case files
├── dotfiles/              # GNU Stow packages for the desktop
├── install/               # archinstall JSON, preflight, bootstrap, boot-time units
├── iso/                   # archiso netinstall profile
├── research/              # background research notes
├── scripts/               # sync and ensure-* reconcilers, screenshot helper
└── tests/                 # shell tests (currently test_sync.sh)
```

- `.agents/` holds agent skills; do not hand-edit what `skills-lock.json` pins.
- `config/` is the source of truth: `packages`, `packages-arch`, `flatpaks-system.list`,
  `flatpaks-user.list`, `protected-packages` (`flatpaks.list` is legacy, system scope).
- `desktop/` holds `Detailed_PC_Report_Without_Submetrics.txt`.
- `docs/` holds `adr/`, `agents/`, `wiki-draft/`, `TROUBLESHOOTING.md`,
  `target-bringup-runbook.md`, `hyprcapture-trial.md`, `dmub-coldboot-casefile.md`,
  `upstream-drm-amd-coldboot-dmub.md`.
- `dotfiles/` has `fuzzel`, `hypr`, `quickshell`, `swaync`, `tabby`, `termfilechooser`, `uwsm`,
  `vicinae`, `xdg`.
- `install/` has `archinstall-desktop.json`, `archinstall-desktop.creds.example.json`,
  `bootstrap.sh`, `preflight.sh`, `greetd-config.toml`, `vconsole.conf`, `amdgpu-late.service`.
- `iso/` has `profiledef.sh`, `packages.x86_64`, `airootfs/`, `README.md`.
- `research/` currently has `office-suites.md`.
- `scripts/` has `sync.sh`, `ensure-packages.sh`, `ensure-flatpaks.sh`, `screenshot-window.sh`.

## Build & Development Commands

Target OS is Arch Linux. Static checks run anywhere with bash and python3.

1. Static checks (no Arch needed):

```bash
bash -n scripts/*.sh install/*.sh && echo STATIC-OK
python3 -m json.tool install/archinstall-desktop.json > /dev/null && echo JSON-OK
python3 -m json.tool install/archinstall-desktop.creds.example.json > /dev/null
./scripts/sync.sh --prune --dry-run
```

2. Install on a fresh Arch live environment:

```bash
chmod +x scripts/*.sh install/*.sh
./install/preflight.sh --vm        # or --target on the 7900 XT box
# EDIT-ME: install/archinstall-desktop.json (device, hostname, timezone)
cp install/archinstall-desktop.creds.example.json /tmp/creds.json   # fill hashes, never commit
archinstall --config install/archinstall-desktop.json --creds /tmp/creds.json
./install/bootstrap.sh             # preflight -> packages -> stow -> flatpaks -> services
```

3. Reconcile packages (manual only, never automatic):

```bash
./scripts/sync.sh                    # install missing only
./scripts/sync.sh --prune --dry-run  # preview extras
./scripts/sync.sh --prune            # remove extras (confirms; honors protected-packages)
```

4. Build the netinstall ISO (on Arch with `archiso`):

```bash
sudo pacman -S --needed archiso
cp /etc/pacman.conf iso/pacman.conf
cp -r /usr/share/archiso/configs/releng/syslinux iso/syslinux
cp -r /usr/share/archiso/configs/releng/efiboot iso/efiboot
sudo mkarchiso -v -w /tmp/luici-iso-tmp -o out/ iso/
```

5. Lint, formatter, package manager for the repo itself: > TODO: none configured beyond
   `bash -n`. [NEEDS TEAM INPUT] (e.g. shellcheck, shfmt).

## Code Style & Conventions

- Languages: Bash (scripts, installer), JSON (archinstall), Lua (Hyprland), QML (Quickshell),
  Markdown (docs). > TODO: document formatting rules per language. [NEEDS TEAM INPUT]
- Hyprland config is native Lua only: `hyprland.lua` plus `lua/` modules loaded with
  `require()`. The hyprlang `.conf` format is deprecated since 0.55; do not add it.
- uwsm users keep environment in `~/.config/uwsm/env` and `~/.config/uwsm/env-hyprland`.
- Dotfiles are GNU Stow packages under `dotfiles/`; root-owned files (e.g. greetd config)
  are not stowable and are deployed by `install/bootstrap.sh`.
- Shell pipelines under `set -o pipefail`: avoid `grep -q` on the right of a pipe (SIGPIPE
  false failures). Fixed twice already in the PCI check and AMD gate.
- Functions run inside `$(...)` must send prompts and chatter to stderr, never stdout.
- Commit messages: Conventional Commits style (`feat:`, `fix:`, `docs:`, `chore:`) with a
  `Refs #N` or `Closes #N` footer.
- Config strictness: `install/archinstall-desktop.json` must match the CURRENT archinstall
  parser (verified on the 2026.09.01 ISO). Rules:
  1. `size`/`start` need a `sector_size` object (`{"unit": "B", "value": 512}`), never null.
  2. `unit` is a fixed enum; there is no Percent or fill-remaining value. Use explicit GiB.
  3. The ESP needs flags `["boot", "esp"]`; `boot` alone is not recognized.
  4. Keep `"silent": false` for first runs so a human reviews disk and users.
- Package names are exact: use `greetd-tuigreet`, not `tuigreet`.
- Browser: `helium-browser-bin` only; Firefox is removed everywhere.

## Architecture Notes

```mermaid
flowchart TD
    ISO[iso/ netinstall image] --> LI[luicipheros-install]
    LI --> PF[install/preflight.sh]
    PF --> AI[archinstall + archinstall-desktop.json]
    AI --> BS[install/bootstrap.sh]
    BS --> ENS[scripts/ensure-packages.sh and ensure-flatpaks.sh]
    BS --> STOW[stow dotfiles/*]
    BS --> SVC[services: greetd, NetworkManager, amdgpu-late optional]
    CFG[config/ desired lists] --> SYNC[scripts/sync.sh]
    SYNC --> ENS
    PROT[config/protected-packages] --> SYNC
```

Desired lists in `config/` declare intent; `luci sync` (`scripts/sync.sh`) realizes it. Default
mode installs missing packages only and never touches dependencies (`-Qqd`). `--prune` also
removes extras after a preview and confirmation, and never removes anything in
`protected-packages` (kernel, firmware, drivers, compositor, networking). System and user
flatpak scopes prune independently. Sync is manual-only by design: no auto-sync on boot.

Desktop stack (locked in v0.1): Hyprland (>= 0.55, native Lua) under uwsm, greetd + tuigreet
login, Vicinae launcher on SUPER+Space (fuzzel fallback), custom Quickshell bar and plugin
host, swaync notifications (kept until the shell has its own center), Tabby terminal,
grim + slurp -> Gradia screenshots, GTK portal file picker (termfilechooser + yazi is opt-in).
Hyprland, lock screen, portals and drivers stay pacman-owned because of PAM/SUID and GL traps.

Disk layout on the target: LUKS + btrfs with subvolumes `@`, `@home`, `@log`, `@pkg`,
`@snapshots`, systemd-boot (per `docs/dmub-coldboot-casefile.md`).

The ISO is a netinstall image: packages are never baked in, so every install gets current
packages. Fixes to `luicipheros-install` reach a booted ISO only via `git pull` plus a copy
(see `iso/README.md`).

Decision record: ADR-0001 locks Arch + scripts. Nix is an optional v0.3 layer; LFS is a
learning side-quest only.

## Testing Strategy

- Static: `bash -n`, `python3 -m json.tool`, `sync.sh --prune --dry-run` (see TESTING.md §0).
- Unit/regression: `tests/test_sync.sh` covers the sync contract. > TODO: confirm how to run it
  and whether it needs Arch; add it to the documented commands. [NEEDS TEAM INPUT]
- VM smoke: QEMU/OVMF, Arch ISO, 4G RAM, 60G disk. PASS means Hyprland (uwsm) loads,
  SUPER+T opens Tabby, SUPER+Space opens Vicinae, Quickshell bar and swaync are visible, and
  Print -> region -> Gradia works.
- ISO loop: boot the built ISO, run `luicipheros-install --vm`; reaching `archinstall` is PASS.
- Target machine: `./install/preflight.sh --target`, then the ROCm/desktop verification list in
  `TESTING.md` §2 (`rocminfo`, PyTorch ROCm, Blender HIP, Ollama, `lpstat -p`, `hyprctl version`).
- Sync contract: install missing only; `--prune --dry-run` previews; `--prune` confirms unless
  `--yes`; honors `protected-packages`; scopes prune independently.
- CI: none yet (planned for v0.3: CI + VM test matrix).

## Security & Compliance

- Secrets: never commit credentials. Copy `archinstall-desktop.creds.example.json` to
  `/tmp/creds.json` and fill password hashes (`openssl passwd -6`). Do not commit hashes.
- Ignored artifacts (`.gitignore`): `iso/pacman.conf`, `iso/syslinux`, `iso/efiboot`, `out/`,
  `screenshotVM/`, `docs/*.pdf`.
- Disk encryption: LUKS on the target. SecureBoot is out of scope for v0.1.
- Privileged paths: PAM/SUID components (lock screen, keyring, greetd) stay system packages.
- AUR surface is kept tiny (yay-bin, vicinae-bin, helium-browser-bin, tabby-bin); review any
  addition.
- Dependency scanning: > TODO: none configured. [NEEDS TEAM INPUT]
- Secret scanning: > TODO: none configured in CI. Scan diffs manually before pushing.
- License: MIT (`LICENSE`) covers original files. Third-party software installed via the lists
  keeps its upstream licenses. Not an official Arch product.

## Agent Guardrails

- Never commit secrets, credentials, password hashes, or local artifacts (VM screenshots,
  runbook PDFs, ISO outputs).
- Never enable auto-sync on boot or add a unit that runs `sync.sh`; manual-only is LOCKED.
- Never remove or weaken `config/protected-packages`, or make `--prune` run without preview
  and confirmation.
- Never re-add Firefox, waybar, kitty, or swappy; they were deliberately removed.
- Never add hyprlang `.conf` Hyprland configs.
- Do not run `archinstall`, `sync.sh --prune`, `mkarchiso`, or anything writing to disks, on
  the host without an explicit user instruction.
- Do not change `install/amdgpu-late.service` enablement; it is DISABLED pending test.
- Do not publish the ISO under Releases until a VM boot reaches archinstall (see `iso/README.md`).
- Do not claim broad hardware compatibility before the matrix passes (ADR-0001).
- Record unverified claims as `> TODO:` or `[NEEDS TEAM INPUT]`; mark target-only results as
  unverified until tested on the target.
- Required reviews: > TODO: no review policy or branch protection (main is unprotected).
  [NEEDS TEAM INPUT]
- Rate limits: > TODO: none defined.
- Log architectural changes in `.agent/CONTINUITY.md` and, when decisions change, in a new ADR.
- Issue tracking uses `gh`; infer the repo from `git remote -v`.

## Extensibility Hooks

- Desired lists in `config/`: add a package or flatpak by editing the list, then `luci sync`.
- Preflight modes: `install/preflight.sh --vm | --target`; bootstrap
  `--preflight-mode=vm|target` and `--no-flatpak`.
- `scripts/sync.sh` flags: `--prune`, `--dry-run`, `--yes`; AUR helper flag (yay-bin default,
  paru supported).
- Quickshell plugin host: `dotfiles/quickshell/plugins/` for ported Noctalia,
  DankMaterialShell and Omarchy widgets.
- Opt-in features: termfilechooser + yazi portal picker (dormant), HyprCapture screenshot trial
  (`docs/hyprcapture-trial.md`), `amdgpu-late.service` (AMD hardware only).
- Planned: hardware profiles under `profiles/` (v0.2), optional Nix layer (v0.3).
- Environment variables: `AQ_DRM_DEVICES` (per-machine, planned via profiles). Feature flags:
  > TODO: none documented. [NEEDS TEAM INPUT]

## Further Reading

- `README.md` – overview, install, roadmap.
- `CONTEXT.md` – glossary and locked decisions.
- `docs/adr/0001-arch-vs-nixos.md` – why Arch + scripts.
- `TESTING.md` – test matrix and results.
- `docs/TROUBLESHOOTING.md` – FAQ from smoke failures (includes the DMUB cold-boot entry).
- `docs/target-bringup-runbook.md` – hardware-day plan.
- `docs/dmub-coldboot-casefile.md` and `docs/upstream-drm-amd-coldboot-dmub.md` – open GPU issue.
- `docs/hyprcapture-trial.md` – reversible screenshot-tool trial.
- `docs/agents/` – issue tracker, triage labels, domain docs.
- `iso/README.md` – ISO build and test.
- archinstall: https://archinstall.archlinux.page/ and
  https://github.com/archlinux/archinstall/blob/master/archinstall/lib/models/device.py
- archinstall man page: https://man.archlinux.org/man/archinstall.1.en
