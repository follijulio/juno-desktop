local home = assert(os.getenv("HOME"), "HOME não definido")
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

local theme = {
    paper = "rgb(fffdf5)",
    ink = "rgb(111111)",
    runtime_bin = config_home .. "/juno/bin",
}

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

function theme.command(name, argument)
    local command = "bash -- " .. shell_quote(theme.runtime_bin .. "/" .. name)
    if argument then
        command = command .. " " .. shell_quote(argument)
    end
    return command
end

return theme
