# 03 — Desktop: Hyprland keyboard-driven shell (DRAFT, uncommitted wiki)

> DRAFT — generated 2026-09-27 from repo files. Do not treat as published docs.
> Anything marked **VERIFY-ON-TARGET** could not be confirmed from the repo
> and must be checked on the real machine before this page goes live.

## Stack at a glance (locked, `CONTEXT.md` + `README.md`)

Hyprland (native Lua `hyprland.lua`, 0.55+) + Vicinae (primary,
Raycast-like, SUPER+Space) + fuzzel (fallback) + Quickshell custom
shell (bar + plugin host) + swaync (kept) + Tabby + Gradia screenshots
+ hyprlock/hypridle + uwsm session + portals — all SUPER-key first.
Removed: Waybar (→ Quickshell bar), kitty (→ Tabby), swappy (→ Gradia),
hyprlang `.conf` (deprecated since 0.55), `wlogout` (left the repos).

## Hyprland Lua config (`dotfiles/hypr/`)

Entry point `~/.config/hypr/hyprland.lua` (stowed from
`dotfiles/hypr/.config/hypr/`), one `require()` per concern:

```lua
require("lua.variables")
require("lua.monitors")
require("lua.look")
require("lua.binds")
require("lua.rules")
require("lua.autostart")
```

- `lua/variables.lua` — edit programs **here, not in binds**:
  `terminal = "tabby"`, `fileManager = "yazi"`,
  `menu = "vicinae toggle || fuzzel"`, `browser = "firefox"`,
  `shotDir = "~/Pictures/Screenshots"`.
- `lua/monitors.lua` — default autodetects every monitor at preferred
  mode (`output = ""`, `mode = "preferred"`, `position = "auto"`,
  `scale = "auto"`). Commented pinned examples for the target desktop
  (`DP-1 2560x1440@165` + `HDMI-A-1 1920x1080@60`) and laptop HiDPI
  (`eDP-1`, scale 1.25). **VERIFY-ON-TARGET**: the pinned target
  outputs/refresh rates are examples, not probed values. v0.2:
  `profiles/<machine>.lua` overrides.
- `lua/look.lua` — gaps (in 4, out 8), 2px borders
  (`active 89b4faee`, `inactive 313244aa`), rounding 8, blur (size 6,
  2 passes), animations on, `dwindle.preserve_split = true`,
  `misc.force_default_wallpaper = 0` + `disable_hyprland_logo`,
  input (`kb_layout us`, `follow_mouse 1`, touchpad natural scroll),
  3-finger horizontal workspace gesture. `dwindle:pseudotile` is
  **gone upstream** — removed after VM smoke reported `unknown config
  key dwindle.pseudotile` (see 04-troubleshooting).
- `lua/rules.lua` — Vicinae floats centered (launcher feel); pavucontrol
  / blueman-manager float.
- `lua/autostart.lua` — on `hyprland.start`: `quickshell`, `swaync`,
  `hypridle`, `wl-paste --type text/image --watch cliphist store`
  (feeds Vicinae clipboard history), `vicinae server` (best-effort,
  `|| true`).

## Keybindings (`lua/binds.lua`, `mainMod = SUPER`)

| Keys | Action |
|---|---|
| SUPER+T | Tabby (`terminal`) |
| SUPER+Space | `vicinae toggle \|\| fuzzel` (primary + fallback) |
| SUPER+SHIFT+D | fuzzel directly |
| SUPER+Q | close window (SUPER+SHIFT+Q intentionally unbound — `wlogout` left the repos; v0.2 session menu moves into the Quickshell shell) |
| SUPER+E | `tabby -e yazi` (fallback `tabby -- -e yazi`) |
| SUPER+N | `swaync-client -t -sw` (panel toggle) |
| SUPER+Escape | `hyprlock` |
| SUPER+1…9 / +SHIFT | workspaces / move to workspace |
| SUPER+HJKL / +SHIFT | focus / move (vim keys); SUPER+F fullscreen, V float-toggle, P pseudo |
| Print | `grim -g "$(slurp)" <shotDir>/shot-<ts>.png && gradia <file>` (region → file → editor) |
| SUPER+S | region → clipboard (`grim … \| wl-copy`) |
| XF86 audio/brightness | `wpctl` / `playerctl` / `brightnessctl` (locked + repeating where applicable) |
| SUPER+scroll, SUPER+drag/resize | workspace cycle, move, resize |

OPEN QUESTION — terminal key: the repo disagrees with itself.
`lua/binds.lua` + `dotfiles/tabby/.../README` say **SUPER+T** (commit
"terminal on SUPER+T (not Return)"); but `install/bootstrap.sh`
post-bootstrap echo and `TESTING.md` §1 PASS line still say
**SUPER+Return**. One of them is stale — confirm on target and fix the
loser before publishing.

## Terminal: Tabby (`dotfiles/tabby/`, AUR `tabby-bin`)

Why Tabby over kitty (`dotfiles/tabby/.config/tabby/README`): built-in
SSH connection manager + tabs, xterm-compatible TERM (no remote
terminfo installs needed). Package: **prebuilt `tabby-bin`** over
source-build `tabby` (`config/packages-arch`); secret store via
`gnome-keyring` (`config/packages`).

This repo ships **NO `config.yaml` on purpose** — even a comments-only
file broke Tabby's theme resolution on first run (null `appearance`
crash, VM smoke Sep 2026). Configure via Tabby's GUI; back up
`~/.config/tabby/config.yaml` yourself. Launcher integration:
fuzzel `terminal = tabby -e`; swaync buttons-grid network button runs
`tabby -e nmtui`. **VERIFY-ON-TARGET**: the `-e` exec flag
(`TESTING.md`).

## Launcher: Vicinae primary, fuzzel fallback

- Vicinae (`dotfiles/vicinae/.config/vicinae/README`, AUR `vicinae`):
  primary Raycast-like launcher, SUPER+Space → `vicinae toggle ||
  fuzzel` so the shell stays usable if the daemon isn't running.
  Autostart best-effort (`vicinae server … || true`). Configured via
  its GUI, not dotfiles. NOTE: Vicinae also ships its own built-in
  Alt+Space shortcut from defaults — keep both or disable it under
  Vicinae Settings → Preferences. v0.2: clipboard + portal limits pass.
- fuzzel (`dotfiles/fuzzel/.config/fuzzel/fuzzel.ini`): fallback on
  SUPER+SHIFT+D; `terminal = tabby -e`; JetBrainsMono Nerd Font,
  Catppuccin-ish palette (bg `1e1e2e`, text `cdd6f4`, selection
  `89b4fa`).

## Bar: Quickshell custom shell + plugin host (`dotfiles/quickshell/`)

`shell.qml` is a minimal top bar (wordmark, plugin row, clock) — it does
not try to be Noctalia or DankMaterialShell; it **hosts ported widgets
from them**. Shared tokens via the `luci` object (`barHeight 30`,
`accent #89b4fa`, `bg #1e1e2e`, `fg #cdd6f4`, `muted #6c7086`,
`fontFamily JetBrainsMono Nerd Font`). Enabled plugins in
`plugins.json` load order (v0.1: `["swayncIndicator"]`).

Porting a widget (`dotfiles/quickshell/.config/quickshell/README.md`):

1. Copy widget QML to `plugins/<name>.qml` (single file; optional
   `property var luci`, fall back to literals so it previews standalone).
2. Add `"<name>"` to `plugins.json`.
3. Reload: `quickshell reload` (or restart the session).

Conventions: one plugin = one bar widget, no global singletons; theme
only from `luci`; async data via `Process`, never blocking loops;
Hyprland state via `import Quickshell.Hyprland` with a fallback text
when the compositor isn't Hyprland (VM smoke). Example plugin
`swayncIndicator.qml`: polls `swaync-client -swb`, shows an unread dot,
click toggles the control center (`swaync-client -t -sw`).

v0.2 roadmap: workspaces widget, system tray, NotificationServer-based
center (which finally lets swaync go).

## Notifier: swaync KEPT — rationale (`CONTEXT.md`, `dotfiles/swaync/`)

The custom shell has **no notification center yet**; the shell shows
only swaync's indicator via `swaync-client`. Drop swaync only once the
shell grows a NotificationServer-based center (v0.2). Until then:

- `config.json`: right-top overlay panel, 380px, 8s timeouts (4s low),
  widgets `title dnd notifications mpris buttons-grid`; buttons-grid =
  poweroff / reboot / `hyprlock` / `tabby -e nmtui` (power menu lives
  here until the v0.2 Quickshell session menu).
- `style.css`: dark base only; full theme (or removal) in v0.2.
- Toggle: SUPER+N (`swaync-client -t -sw`).

## Screenshots: grim + slurp → Gradia

Region capture `grim -g "$(slurp)"` to `~/Pictures/Screenshots/`, then
open in the **Gradia editor** (Arch Extra, `config/packages` + ROCm
verify `gradia --help`). `swappy` removed. SUPER+S variant pipes to
`wl-copy` instead.

## Session: uwsm env, lock/idle, portals

- uwsm (`dotfiles/uwsm/`): toolkit vars in `env` (`XCURSOR_SIZE 24`,
  `HYPRCURSOR_SIZE 24`, Wayland backends for Qt/GDK/Electron/Firefox —
  Tabby is Electron, runs native Wayland via the hint); Hyprland/AQ
  vars in `env-hyprland` (`AQ_DRM_DEVICES=/dev/dri/card1:/dev/dri/card0`
  to prefer the discrete card, `AMD_VULKAN_ICD=RADV`). Hyprland-wiki
  rule: keep these OUT of `hyprland.lua`. v0.2: per-machine overrides.
  **VERIFY-ON-TARGET**: the `card1:card0` order assumes the 7900 XT
  enumerates as `card1` — confirm with `ls /dev/dri/` on target.
- Lock/idle: `hyprlock.conf` (screenshot-background blur, centered
  input + `$TIME` label), `hypridle.conf` (lock 10 min → screen off
  12 min → suspend 30 min). Both pacman-owned per ADR-0001.
- Portals (`dotfiles/xdg/.../hyprland-portals.conf`): Hyprland-first
  order (`default = hyprland;gtk`; FileChooser → gtk, Screenshot /
  ScreenCast → hyprland). System portals stay pacman-owned.
