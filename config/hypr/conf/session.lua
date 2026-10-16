local theme = require("conf.theme")

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("JUNO_RUNTIME_BIN", theme.runtime_bin)
local home = assert(os.getenv("HOME"))
local function prepend_paths(variable, prefixes, fallback)
    local paths, seen = {}, {}
    local function add(path)
        if not seen[path] then
            paths[#paths + 1] = path
            seen[path] = true
        end
    end
    for _, path in ipairs(prefixes) do add(path) end
    for path in (os.getenv(variable) or fallback):gmatch("[^:]+") do add(path) end
    hl.env(variable, table.concat(paths, ":"))
end
prepend_paths("PATH", { home .. "/.local/bin" }, "/usr/local/bin:/usr/bin:/bin")
prepend_paths("XDG_DATA_DIRS", { home .. "/.local/share/flatpak/exports/share", "/var/lib/flatpak/exports/share" },
    "/usr/local/share:/usr/share")

-- Register startup instead of executing it while loading/validating the config.
hl.on("hyprland.start", function()
    hl.exec_cmd(theme.command("session-start"))
end)
