-- hyprland.lua — LuicipherOS v0.1 Hyprland config (native Lua, Hyprland 0.55+).
-- hyprlang (hyprland.conf) is deprecated since 0.55; this file is the entry
-- point Hyprland loads from ~/.config/hypr/hyprland.lua. Each concern lives
-- in its own module under lua/ and is pulled in with require().
-- Locked stack: Tabby (SUPER+Return), Vicinae primary on SUPER+Space
-- (+fuzzel fallback), Quickshell bar, swaync, Gradia screenshots,
-- hyprlock/hypridle, uwsm session. Env vars live in ~/.config/uwsm/env
-- and env-hyprland (stowed from dotfiles/uwsm), NOT here.

require("lua.variables")
require("lua.monitors")
require("lua.look")
require("lua.binds")
require("lua.rules")
require("lua.autostart")
