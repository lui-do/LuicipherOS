# CONTEXT.md (LuicipherOS v0.1 draft — to be sharpened in grill)

Glossary only. No implementation details.

## Terms

- **LuicipherOS**: Arch-based Hyprland OS-config in this repo (dotfiles + installer + declarative lists), not a forked distro in v0.1.
- **Desired list**: source-of-truth text files (`config/packages`, `config/packages-arch`, `config/flatpaks-system.list`, `config/flatpaks-user.list`). Editing them declares intent; sync realizes it.
- **Sync (luci sync)**: idempotent reconciler in `scripts/sync.sh`. Default = install missing only. `--prune` = also uninstall extras. LOCKED v0.1: manual-only, no auto-sync on boot (grill Q5).
- **Protected package**: base package never auto-removed (`config/protected-packages`: kernel, firmware, drivers, compositor, networking).
- **Extra**: explicitly installed package/app not in desired + protected sets. Previewed before prune, never silently removed.
- **Target machine**: Ryzen 5 9600X + ASUS B650E-PLUS WIFI + RX 7900 XT 20GB. v0.1 is tuned here, tested elsewhere.
- **Hardware profile**: per-machine overlay (monitors, `AQ_DRM_DEVICES`, power) under `profiles/` (v0.2).
- **Keyboard-driven shell**: Hyprland + Vicinae (primary, Raycast-like) + fuzzel (fallback) + bar (waybar) + swaync + lock/idle + portals, all SUPER-key first.

## Locked in grill (v0.1)

- launcher: Vicinae (user already uses it; Raycast-like layer). fuzzel stays as fallback system launcher.
- notifier: swaync (customizable via CSS/JSON/widgets — yes, modifiable).
- AUR helper: yay-bin default (precompiled, docs); paru supported via helper flag.
- flatpak scope: SPLIT — system list + user list.
- sync: manual-only, no auto-sync on boot.
- ADR-0001: LOCKED Arch + scripts. Nix reproducibility = optional v0.3 layer on Arch + breakage guards. LFS = learning side-quest, not v0.1 path.

## Open for v0.2

- Vicinae keybind/clipboard on Hyprland (manual bind, portal limits)
- swaync theme (CSS) to match Waybar
- hardware profiles, Hyprland Lua monitors
