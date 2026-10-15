-- Juno Desktop: Arch Linux / Hyprland 0.56.x.
-- Resolve modules beside this file, including when validating a staged copy.
local source = debug.getinfo(1, "S").source
local config_dir = assert(source:sub(2):match("^(.*)/[^/]+$"), "Caminho da configuração Juno inválido")
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

require("conf.monitors")
require("conf.appearance")
require("conf.input")
require("conf.bindings")
require("conf.session")
