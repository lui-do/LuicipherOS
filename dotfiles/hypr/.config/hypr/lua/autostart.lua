-- lua/autostart.lua — session services. Quickshell replaces waybar;
-- swaync stays (kept for v0.1: the custom shell has no notification
-- center yet). cliphist feeds Vicinae clipboard history.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("vicinae server 2>/dev/null || true")
end)
