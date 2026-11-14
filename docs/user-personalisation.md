# Personalising your LuicipherOS desktop

Who this is for: any user of a LuicipherOS system (`work`, `luci`, or a new account).

## The model in one paragraph

LuicipherOS ships **one shared base config** for every user — it is managed by the
repo (GNU Stow symlinks) and is updated centrally. Your personalisation never edits
those files. Instead, each app also loads an **override file from your own home**,
under `$XDG_CONFIG_HOME/luicipher/` (normally `~/.config/luicipher/`). Override files
are real files that belong to you: they are never stow-managed and are never touched
by system or dotfile updates. Everything in the base stays default unless you list a
different value; **last value wins**.

| App | Base (shared, read-only for you) | Your override |
| --- | --- | --- |
| Hyprland | `~/.config/hypr/hyprland.lua` + `lua/` modules | `~/.config/luicipher/hypr/overrides.lua` |
| Quickshell bar | `~/.config/quickshell/tokens.json` | `~/.config/luicipher/quickshell/tokens.json` |

A brand-new user gets the full desktop with zero setup — overrides are optional.

## Hyprland overrides

`hyprland.lua` loads your `overrides.lua` **last**, so any `hl.*` call in it wins
over the base. The file is plain Lua.

```bash
$EDITOR ~/.config/luicipher/hypr/overrides.lua
hyprctl reload        # apply (or just save: Hyprland watches its config)
```

Examples — uncomment or adapt; delete everything to return to the base:

```lua
-- thicker borders and more gaps
hl.config({ general = { border_size = 4, gaps_in = 6, gaps_out = 10 } })

-- a different keyboard layout than the cz/us default
hl.config({ input = { kb_layout = "us" } })

-- an extra keybind on top of the base set
hl.bind({ key = "RETURN", modifiers = { "SUPER", "SHIFT" },
          dispatcher = "exec", argument = "kitty" })
```

Bad Lua in the file cannot break your session: it is loaded inside `pcall`, the
base config survives, and the failure is printed to the session log.

## Quickshell bar tokens

Your `tokens.json` overrides the shared one **key by key** — list only what you
change. Available keys (with the shipped defaults):

```json
{
  "barHeight": 30,
  "accent": "#89b4fa",
  "bg": "#1e1e2e",
  "fg": "#cdd6f4",
  "muted": "#6c7086",
  "fontFamily": "JetBrainsMono Nerd Font"
}
```

```bash
mkdir -p ~/.config/luicipher/quickshell
$EDITOR ~/.config/luicipher/quickshell/tokens.json
```

**No reload needed** — the bar watches both files and updates the moment you save
(bigger bar? change `barHeight` and watch it happen live). Delete the file to go
back to the base look. A malformed file is ignored with a console warning and the
previous value stays.

## Other personalisation that already exists

- **Program choices** (terminal, browser, launcher commands) live in the base's
  `lua/variables.lua`; per-user changes go in `overrides.lua` style via the same
  last-wins mechanism where supported — ask on the issue tracker for an app that
  lacks an override hook yet.
- **Session environment** (Wayland vars, PATH) is per-user already:
  `~/.config/uwsm/env` and `env-hyprland`.
- **Vicinae theme following the same palette** is planned (#22); until then it is
  configured in Vicinae's own settings.

## Troubleshooting

1. **"cannot open …/hyprland.lua" banner after a dotfile update** — the updater
   replaced files faster than Hyprland's watcher could read them; run `hyprctl
   reload` once, the banner clears.
2. **Override seems ignored (Hyprland)** — check `hyprctl getoption <name>` for the
   live value; the log line `luicipher: user overrides applied` means the file
   loaded, `overrides.lua FAILED` means Lua errored (base config is still intact).
3. **Override seems ignored (Quickshell)** — validate the JSON: `python3 -m
   json.tool ~/.config/luicipher/quickshell/tokens.json` must not error.

## The one rule

Edit files under `~/.config/luicipher/` — **never** edit anything inside the
stowed `~/.config/hypr/` or `~/.config/quickshell/` targets; those belong to the
repo and your changes would be overwritten on the next update.
