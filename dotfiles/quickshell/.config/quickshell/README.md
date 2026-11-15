# LuicipherOS Quickshell shell v0.1 — custom bar + plugin host

`shell.qml` is a minimal top bar (wordmark, plugin row, clock). It does not
try to be Noctalia or DankMaterialShell; it hosts ported widgets from them.

## Configuration layering (shared base + per-user override)

Design tokens (bar height, palette, font) resolve in three layers — later wins,
key by key:

1. **Inline defaults** in `shell.qml` (`tokenDefaults`) — fail-safe floor.
2. **`tokens.json`** (this directory) — the **base for all users**; stow-managed,
   so it updates with the repo. Edit here to change the distro default.
3. **`$XDG_CONFIG_HOME/lui/quickshell/tokens.json`** — **per-user
   override**: a real file, never stow-managed, survives updates. Contains only
   the keys the user changes:

   ```bash
   mkdir -p ~/.config/lui/quickshell
   echo '{ "barHeight": 40 }' > ~/.config/lui/quickshell/tokens.json
   ```

Both JSON files **hot-reload on save** (FileView watchers); no restart needed.
The Hyprland side mirrors this: `$XDG_CONFIG_HOME/lui/hypr/overrides.lua`
(last-wins, see `dotfiles/hypr`). A new user gets the whole base config just by
logging in; personalisation never forks the shared files.

## RAM discipline (keep the shell flat as plugins grow)

Measured baseline: ~190 MB (single process). The rules that keep growth bounded:

- **Bar plugins load through `Loader { asynchronous: true }`** — instantiation
  never blocks shell startup (plugin rows are always visible, so this is the
  right primitive here). For plugins that live in **on-demand windows** (launcher,
  dash, OSD), Quickshell's `LazyLoader` (or plain `Loader { active: win.visible }`)
  keeps their whole tree out of RAM until first opened — note `LazyLoader` is a
  QtObject, not an Item, so use it inside a window, not as a Repeater delegate.
- **Images set `sourceSize`** to display size (a full-res 4K wallpaper in an
  `Image` costs tens of MB).
- **Lists use `ListView`** (recycles delegates), never `Column + Repeater` for
  long or dynamic models.
- **Timers stop when their widget is hidden** (`running: visible`).
- **Measure, don't guess**:
  ```bash
  watch -n 5 'ps -o rss= -p $(pgrep -x quickshell) | awk "{printf \"%.0f MB\n\", \$1/1024}"'
  ```
  Check it before/after adding any plugin; if a plugin adds >20 MB idle, gate
  its instantiation or unload its service when hidden.

## Porting a widget (Noctalia / DankMaterialShell / Omarchy)

1. Copy the widget QML into `plugins/<name>.qml` (single file; inline any
   small helpers, or put them beside it and `import "./helpers"`).
2. Give it an optional `property var lui` — the shell injects palette +
   metrics (`barHeight`, `accent`, `bg`, `fg`, `muted`, `fontFamily`) as a
   **binding**, so the plugin follows token hot-reloads.
   Fall back to literals so the file also previews standalone.
3. Add `"<name>"` to `plugins.json` (load order = array order).
4. Reload: `quickshell reload` (or restart the session).

Conventions that keep ports cheap:

- One plugin = one bar widget, no global singletons.
- Read theme only from `lui`, never hardcode the palette twice.
- Async data via `Process` (see `swayncIndicator.qml`), never blocking loops.
- Hyprland state via Quickshell's Hyprland integration (`import Quickshell.Hyprland`);
  keep a fallback text when the compositor isn't Hyprland (VM smoke).

## v0.2 roadmap

Workspaces widget, system tray, and a NotificationServer-based center
(which is what finally lets swaync go). Until then swaync stays.
