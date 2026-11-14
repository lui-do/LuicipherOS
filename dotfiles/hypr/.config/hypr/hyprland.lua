-- hyprland.lua — LuicipherOS v0.1 Hyprland config (native Lua, Hyprland 0.55+).
-- hyprlang (hyprland.conf) is deprecated since 0.55; this file is the entry
-- point Hyprland loads from ~/.config/hypr/hyprland.lua. Each concern lives
-- in its own module under lua/ and is pulled in with require().
-- Locked stack: Tabby (SUPER+T), Vicinae primary on SUPER+Space
-- (+fuzzel fallback), Quickshell bar, swaync, Gradia screenshots,
-- hyprlock/hypridle, uwsm session. Env vars live in ~/.config/uwsm/env
-- and env-hyprland (stowed from dotfiles/uwsm), NOT here.

require("lua.variables")
require("lua.monitors")
require("lua.look")
require("lua.binds")
require("lua.rules")
require("lua.autostart")

-- Per-user overrides (shared base + last-wins, see quickshell README for the
-- same pattern). Everything above is the stow-managed base shared by all users;
-- a user adds a real, NEVER-stowed file at
--   $XDG_CONFIG_HOME/luicipher/hypr/overrides.lua
-- containing plain Lua that runs LAST, so any hl.config{...} value overrides
-- the base (example: hl.config({ general = { border_size = 4 } })).
-- io.open + dofile were verified to work in Hyprland's Lua sandbox (0.57).
-- pcall isolates a broken override: the base config still loads, and the
-- failure is printed to the session log.
local function apply_user_overrides()
  local cfg = os.getenv("XDG_CONFIG_HOME")
  if cfg == nil or cfg == "" then
    cfg = (os.getenv("HOME") or "") .. "/.config"
  end
  local path = cfg .. "/luicipher/hypr/overrides.lua"
  local probe = io.open(path, "r")
  if probe == nil then return end          -- no override file: pure base
  probe:close()
  local ok, err = pcall(dofile, path)
  if not ok then
    print("luicipher: overrides.lua FAILED (base config kept): " .. tostring(err))
  else
    print("luicipher: user overrides applied")
  end
end
apply_user_overrides()
