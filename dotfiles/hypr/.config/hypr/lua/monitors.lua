-- lua/monitors.lua — monitor setup. Default autodetects every monitor at
-- preferred mode; uncomment per-machine entries for a pinned layout.
-- v0.2: profiles/<machine>.lua overrides via require().
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Target desktop (RX 7900 XT) pinned example:
-- hl.monitor({ output = "DP-1",     mode = "2560x1440@165", position = "0x0",    scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",  position = "2560x0", scale = 1 })
-- Laptop HiDPI example (v0.2):
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.25 })
