local theme = require("conf.theme")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("JUNO_RUNTIME_BIN", theme.runtime_bin)
local home = assert(os.getenv("HOME"))
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"))
hl.env("XDG_DATA_DIRS", home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:" ..
    (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"))

-- Register startup instead of executing it while loading/validating the config.
hl.on("hyprland.start", function()
    hl.exec_cmd(theme.command("session-start"))
end)
