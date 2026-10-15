#!/usr/bin/env bash
# Derive hardware modules without modifying the installed base configuration.
juno_build_waybar_config() {
    local base=$1 output=$2 sysfs_root=${3:-/sys}
    local has_battery=false has_backlight=false supply backlight
    for supply in "$sysfs_root"/class/power_supply/*/type; do
        [[ -r $supply ]] || continue
        if [[ $(< "$supply") == Battery ]]; then has_battery=true; break; fi
    done
    for backlight in "$sysfs_root"/class/backlight/*; do
        if [[ -d $backlight ]]; then has_backlight=true; break; fi
    done
    jq --argjson battery "$has_battery" --argjson backlight "$has_backlight" '
        .["modules-right"] |= (
            (map(select(. != "battery" and . != "backlight" and . != "custom/session")))
            + (if $battery then ["battery"] else [] end)
            + (if $backlight then ["backlight"] else [] end)
            + ["custom/session"]
        )' "$base" > "$output"
}
