-- Titan's root: an explicit TITAN_ROOT, a packaged install, or the personal checkout.
local function exists(path) local f=io.open(path,"r"); if f then f:close(); return true end; return false end
TITAN_ROOT = os.getenv("TITAN_ROOT")
 or (exists("/usr/share/titan/version") and "/usr/share/titan")
 or (os.getenv("HOME") .. "/dotfiles")
hl.env("TITAN_ROOT", TITAN_ROOT)   -- inherited by the shell and every launched script
local base = os.getenv("HOME") .. "/.config/hypr/"
dofile(base .. "appearance.lua")
dofile(base .. "input.lua")
dofile(base .. "bindings.lua")
dofile(base .. "rules.lua")
hl.monitor({output="", mode="preferred", position="auto", scale="1"})
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.on("hyprland.start", function()
    hl.exec_cmd(TITAN_ROOT .. "/scripts/session-start")
end)
-- The user's own overrides load last (~/.config/titan/hypr.lua); Titan never edits this file.
local user=(os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME").."/.config").."/titan/hypr.lua"
local overrides=io.open(user,"r")
if overrides then overrides:close(); dofile(user) end
