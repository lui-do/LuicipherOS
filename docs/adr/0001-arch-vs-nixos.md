# ADR-0001: Arch + declarative scripts for v0.1, not NixOS or LFS

Date: 2026-09-21 | Status: accepted (locked in grill)

## Context

LuicipherOS needs Hyprland + declarative apps (`packages` + `flatpaks.list` with add→install, remove→uninstall) on Ryzen 9600X + RX 7900 XT, broadly compatible with laptops/desktops. Options: (a) Arch + archinstall + dotfiles + sync scripts, (b) Nix on Arch, (c) full NixOS, (d) LFS.

## Decision

v0.1 = (a) Arch-native + Nix-style files (not NixOS). Own bootstrap + dotfiles, ride Arch repos + `linux-firmware`. Keep Hyprland/lock/portals/drivers on pacman. (b) Nix on Arch optional in v0.3 for dev tools only (reproducibility layer, not base). (c) NixOS experimental flake later. (d) LFS = learning side-quest only, never v0.1 path.

## Rationale — LFS learning vs Nix reproducibility + break prevention

- Better for shipping: Nix reproducibility ON Arch + guards. LFS teaches toolchain/compile order but ships no OS faster and adds security/update burden solo.
- Break prevention on Arch (locked): manual-only `luci sync`, `protected-packages`, explicit-only prune + confirm + `--dry-run`, tiny AUR surface (yay-bin + vicinae), weekly `Syu` test + `last-known-good` tag, Timeshift/Snapper snapshot before sync, separate `/home`.
- Nix GL/PAM traps stay: `/run/opengl-driver` + nixGL for GPU apps, hyprlock/keyring must stay system — hence Nix only for CLI/dev/dotfiles later.

## Consequences

- Must own `sync.sh` prune guardrails (`protected-packages`, explicit-only, confirm).
- Weekly `pacman -Syu` test on target + `last-known-good` tag; pin AUR surface tiny.
- Compat claim limited until matrix passes: target + AMD laptop + Intel laptop + VM.
