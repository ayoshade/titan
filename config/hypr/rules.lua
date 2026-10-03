-- Titan window rules.
-- The Quickshell Settings window floats centred at its designed size.
hl.window_rule({
    name  = "titan-settings",
    match = { title = "^Titan Settings$" },
    float = true,
    center = true,
    size = { 820, 560 },
})
