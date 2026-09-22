-- lua/rules.lua — window rules. Vicinae floats centered (launcher feel);
-- dialogs and helpers float.
hl.window_rule({
    name  = "vicinae-launcher",
    match = { title = "Vicinae" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "float-helpers",
    match = { class = "(pavucontrol|blueman-manager)" },
    float = true,
})
