local theme = require("conf.theme")

hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        col = { active_border = theme.ink, inactive_border = theme.ink },
        layout = "dwindle",
        resize_on_border = true,
        allow_tearing = false,
    },
    decoration = {
        rounding = 0,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
        shadow = { enabled = false },
        blur = { enabled = false },
        motion_blur = { enabled = false },
        glow = { enabled = false },
        dim_inactive = false,
        dim_modal = false,
        dim_special = 0,
    },
    animations = { enabled = false },
    dwindle = { preserve_split = true },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = theme.paper,
        font_family = "Roboto",
    },
})
