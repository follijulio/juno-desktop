local theme = require("conf.theme")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("JUNO_RUNTIME_BIN", theme.runtime_bin)

-- Register startup instead of executing it while loading/validating the config.
hl.on("hyprland.start", function()
    hl.exec_cmd(theme.command("session-start"))
end)
