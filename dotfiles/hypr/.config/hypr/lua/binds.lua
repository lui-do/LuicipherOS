-- lua/binds.lua — all keybindings. Locked: SUPER+Space Vicinae,
-- SUPER+Return Tabby, SUPER 1-9 workspaces, Print -> Gradia.
local mainMod = "SUPER"

-- --- apps (locked: SUPER+T Tabby, SUPER+Space Vicinae) ---
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + Q",       hl.dsp.window.close())
-- SUPER+SHIFT+Q intentionally unbound: wlogout left the repos Sep 2026.
-- v0.2: session menu lives in the Quickshell shell (power/reboot remain
-- in the swaync buttons-grid until then).
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd(terminal .. " -e yazi || " .. terminal .. " -- -e yazi"))
hl.bind(mainMod .. " + N",       hl.dsp.exec_cmd("swaync-client -t -sw"))
hl.bind(mainMod .. " + Escape",  hl.dsp.exec_cmd("hyprlock"))

-- --- workspaces 1-9 (+ move with SHIFT) ---
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

-- --- focus / move (vim keys) ---
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

-- --- screenshots: region -> file -> Gradia editor; SUPER+S -> clipboard ---
hl.bind("Print", hl.dsp.exec_cmd(
    "mkdir -p " .. shotDir .. " && f=" .. shotDir .. "/shot-$(date +%Y%m%d-%H%M%S).png"
    .. " && grim -g \"$(slurp)\" \"$f\" && gradia \"$f\""
))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy"))

-- --- media / brightness ---
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- --- mouse ---
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
