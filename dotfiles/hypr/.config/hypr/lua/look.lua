-- lua/look.lua — gaps, borders, blur, animations. v0.2: full theme pass
-- shared with the Quickshell shell (same palette tokens live there).
hl.config({
    general = {
        gaps_in    = 4,
        gaps_out   = 8,
        border_size = 2,
        col = {
            active_border   = "rgba(89b4faee)",
            inactive_border = "rgba(313244aa)",
        },
        layout = "dwindle",
    },

    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        -- NOTE: pseudotile was removed upstream (see ConfigValues.cpp);
        -- preserve_split covers the sticky-split behavior.
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.curve("ease", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "ease" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "ease" })

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
