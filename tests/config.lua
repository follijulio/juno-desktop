-- Language/API smoke test only. Native Hyprland remains the parser of record.
local root = assert(arg[1], "Informe a raiz do projeto")
local bindings, settings, events, environment = {}, {}, {}, {}
local monitor, executions
executions = 0
local fake_home = "/home/Juno com espaços e 'aspas'"
os.getenv = function(name)
    if name == "HOME" then return fake_home end
    return nil
end
local function dispatcher(name)
    return function(value) return { name = name, value = value } end
end
hl = {
    config = function(config)
        for key, value in pairs(config) do settings[key] = value end
    end,
    monitor = function(config) monitor = config end,
    env = function(name, value) environment[name] = value end,
    bind = function(key, action, options)
        assert(not bindings[key], "Atalho duplicado: " .. key)
        bindings[key] = { action = action, options = options }
    end,
    on = function(event, callback)
        assert(not events[event], "Evento duplicado: " .. event)
        events[event] = callback
    end,
    exec_cmd = function(command)
        executions = executions + 1
        assert(command:find("/session-start'", 1, true), "Autostart inesperado")
    end,
    dsp = {
        exec_cmd = dispatcher("exec"),
        focus = dispatcher("focus"),
        layout = dispatcher("layout"),
        window = {
            close = dispatcher("close"), fullscreen = dispatcher("fullscreen"),
            float = dispatcher("float"), move = dispatcher("move"),
            drag = dispatcher("drag"), resize = dispatcher("resize"),
        },
    },
}

dofile(root .. "/config/hypr/hyprland.lua")
assert(executions == 0, "Carregar configuração não pode iniciar processos")
assert(settings.decoration.rounding == 0)
assert(settings.decoration.blur.enabled == false)
assert(settings.decoration.shadow.enabled == false)
assert(settings.animations.enabled == false)
assert(settings.input.kb_layout == "br" and settings.input.kb_model == "abnt2")
assert(monitor.mode == "preferred" and monitor.position == "auto")
assert(bindings["SUPER + D"] and bindings["SUPER + L"])
assert(bindings["SUPER + SHIFT + 0"].action.value.workspace == 10)
assert(bindings["SUPER + D"].action.value:find("'\\''aspas'\\''", 1, true), "Aspas do HOME precisam ser protegidas")
assert(environment.JUNO_RUNTIME_BIN == fake_home .. "/.config/juno/bin")
assert(type(events["hyprland.start"]) == "function")
events["hyprland.start"]()
assert(executions == 1)
print("Configuração Lua: módulos, atalhos, caminhos e autostart conferidos (stub; não substitui Hyprland).")
