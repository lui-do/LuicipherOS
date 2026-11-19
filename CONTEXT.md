# CONTEXT.md (LuicipherOS v0.1 draft — to be sharpened in grill)

Glossary only. No implementation details.

## Terms

- **LuicipherOS**: Arch-based Hyprland OS-config in this repo (dotfiles + installer + declarative lists), not a forked distro in v0.1.
- **Desired list**: source-of-truth text files (`config/packages`, `config/packages-arch`, `config/flatpaks-system.list`, `config/flatpaks-user.list`). Editing them declares intent; sync realizes it.
- **Sync (lui sync)**: idempotent reconciler in `scripts/sync.sh`. Default = install missing only. `--prune` = also uninstall extras. Scopes: `--system` (shared packages + system flatpaks, admin `luci`), `--user [ACCOUNT]` (user flatpaks + launcher entries, default invoking account). LOCKED v0.1: manual-only, no auto-sync on boot (grill Q5).
- **System scope**: everything shared by every profile — pacman/AUR packages, system flatpaks, system services, the model store. Reconciled by `lui sync --system` as `luci`.
- **User scope**: one account's personal layer — user flatpaks, `lui-local-*.desktop` entries, dotfiles, agent sessions/keys. Reconciled by `lui sync --user` (or `--user ACCOUNT` from the admin). `work` runs it without sudo.
- **AI stack (ADR-0002)**: system-wide `llama-cpp` (Vulkan) + `llama-swap` endpoint on `127.0.0.1:12434`, with Goose and the model weights available to every profile. Local-only by default; telemetry off; per-user cloud keys only.
- **Model alias**: `general`, `coding`, `coding-hq` (alias of `general`), `research`. Weights live in `config/models.json` and `/var/lib/llm/models`; aliases select prompt/context, not a second copy except where a file differs.
- **Request queue** (planned): `~/.config/lui/packages.request` written by a non-admin user, reviewed by `luci` with `lui sync --system --review`; keeps package changes declarative and admin-approved.
- **Protected package**: base package never auto-removed (`config/protected-packages`: kernel, firmware, drivers, compositor, networking).
- **Extra**: explicitly installed package/app not in desired + protected sets. Previewed before prune, never silently removed.
- **Target machine**: Ryzen 5 9600X + ASUS TUF GAMING B650E-PLUS WIFI + RX 7900 XT 20GB. v0.1 is tuned here, tested elsewhere.
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
- AI stack (ADR-0002): LOCKED local-first. System-wide `llama-cpp` (Vulkan) + `llama-swap` + Goose; three weight sets exposed as `general`, `coding`, `coding-hq`, `research`; sessions and cloud keys are user-only; no silent cloud fallback; telemetry off; weights downloaded only by `lui ai sync`; `lui ai disable` stops the endpoint, `disable --prune` is the only definitive uninstall.

## Open for v0.2

- screenshot tool choice: grim->Gradia (current default) vs Hyprland
  HyprCapture trial (see docs/hyprcapture-trial.md) — user judges by feel
- screen recording: user choice, self-installed (OpenScreen Recorder),
  never default (anti-bloat)
- shell workspaces widget, tray, NotificationServer center (then drop swaync)
- swaync CSS theme (only if still kept)
- hardware profiles, Hyprland Lua monitor overrides
- Vicinae clipboard on Hyprland (portal limits)
