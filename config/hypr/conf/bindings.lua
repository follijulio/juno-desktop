local theme = require("conf.theme")
local mod = "SUPER"

local function command(key, name, argument, options)
    hl.bind(key, hl.dsp.exec_cmd(theme.command(name, argument)), options or {})
end

hl.bind(mod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("thunar"))
hl.bind(mod .. " + B", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
command(mod .. " + D", "launcher")
command(mod .. " + L", "lock")
command(mod .. " + W", "wallpaper")
command(mod .. " + Escape", "power-menu")
command("Print", "screenshot", "save")
command("SHIFT + Print", "screenshot", "full")
command("CTRL + Print", "screenshot", "copy")

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
    hl.bind(mod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local repeat_key = { locked = true, repeating = true }
command("XF86AudioRaiseVolume", "audio", "up", repeat_key)
command("XF86AudioLowerVolume", "audio", "down", repeat_key)
command("XF86AudioMute", "audio", "mute", { locked = true })
command("XF86AudioMicMute", "audio", "mic-mute", { locked = true })
command("XF86MonBrightnessUp", "brightness", "up", repeat_key)
command("XF86MonBrightnessDown", "brightness", "down", repeat_key)
