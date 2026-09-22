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
- **Keyboard-driven shell**: Hyprland (native Lua `hyprland.lua`, 0.55+) + Vicinae (primary, Raycast-like, SUPER+Space) + fuzzel (fallback) + Quickshell custom shell (bar + plugin host) + swaync + Tabby + Gradia screenshots + lock/idle + portals, all SUPER-key first.

## Locked in grill (v0.1)

- launcher: Vicinae (user already uses it; Raycast-like layer). fuzzel stays as fallback system launcher. Toggle: SUPER+Space.
- bar: custom Quickshell `shell.qml` (framework from Arch Extra) + `plugins/` host for ported Noctalia / DankMaterialShell / Omarchy widgets. Waybar removed.
- terminal: Tabby (AUR tabby-bin prebuilt; SSH manager + tabs; xterm TERM, no remote terminfo installs). kitty removed.
- screenshots: grim + slurp region capture -> file -> Gradia editor (Extra). swappy removed.
- notifier: swaync KEPT for v0.1 (custom shell has no notification center yet; shell shows its indicator via swaync-client). Drop only once the shell grows a NotificationServer-based center (v0.2).
- Hyprland config: native Lua only (`hyprland.lua` + `lua/` modules via require()); hyprlang `.conf` deprecated since 0.55. uwsm users keep env in `~/.config/uwsm/env{,-hyprland}`.
- AUR helper: yay-bin default (precompiled, docs); paru supported via helper flag.
- flatpak scope: SPLIT — system list + user list.
- sync: manual-only, no auto-sync on boot.
- ADR-0001: LOCKED Arch + scripts. Nix reproducibility = optional v0.3 layer on Arch + breakage guards. LFS = learning side-quest, not v0.1 path.

## Open for v0.2

- shell workspaces widget, tray, NotificationServer center (then drop swaync)
- swaync CSS theme (only if still kept)
- hardware profiles, Hyprland Lua monitor overrides
- Vicinae clipboard on Hyprland (portal limits)
