# LuicipherOS Quickshell shell v0.1 — custom bar + plugin host

`shell.qml` is a minimal top bar (wordmark, plugin row, clock). It does not
try to be Noctalia or DankMaterialShell; it hosts ported widgets from them.

## Porting a widget (Noctalia / DankMaterialShell / Omarchy)

1. Copy the widget QML into `plugins/<name>.qml` (single file; inline any
   small helpers, or put them beside it and `import "./helpers"`).
2. Give it an optional `property var luci` — the shell injects palette +
   metrics (`barHeight`, `accent`, `bg`, `fg`, `muted`, `fontFamily`).
   Fall back to literals so the file also previews standalone.
3. Add `"<name>"` to `plugins.json` (load order = array order).
4. Reload: `quickshell reload` (or restart the session).

Conventions that keep ports cheap:

- One plugin = one bar widget, no global singletons.
- Read theme only from `luci`, never hardcode the palette twice.
- Async data via `Process` (see `swayncIndicator.qml`), never blocking loops.
- Hyprland state via Quickshell's Hyprland integration (`import Quickshell.Hyprland`);
  keep a fallback text when the compositor isn't Hyprland (VM smoke).

## v0.2 roadmap

Workspaces widget, system tray, and a NotificationServer-based center
(which is what finally lets swaync go). Until then swaync stays.
