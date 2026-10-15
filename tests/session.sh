#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
command -v jq >/dev/null || { printf 'jq necessário para testar a configuração real da Waybar.\n' >&2; exit 1; }
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
# shellcheck source=../config/juno/lib/waybar.sh
source "$ROOT/config/juno/lib/waybar.sh"
mkdir -p "$TEST_ROOT/sys/class/power_supply" "$TEST_ROOT/sys/class/backlight"
juno_build_waybar_config "$ROOT/config/waybar/config.jsonc" "$TEST_ROOT/waybar.json" "$TEST_ROOT/sys"
jq -e '.["modules-right"] | index("battery") == null and index("backlight") == null' "$TEST_ROOT/waybar.json" >/dev/null
printf 'OK: Waybar sem módulos de hardware inexistente\n'
mkdir "$TEST_ROOT/sys/class/power_supply/BAT0" "$TEST_ROOT/sys/class/backlight/screen"
printf 'Battery\n' > "$TEST_ROOT/sys/class/power_supply/BAT0/type"
juno_build_waybar_config "$ROOT/config/waybar/config.jsonc" "$TEST_ROOT/waybar.json" "$TEST_ROOT/sys"
jq -e '.["modules-right"] | index("battery") != null and index("backlight") != null and .[-1] == "custom/session"' "$TEST_ROOT/waybar.json" >/dev/null
printf 'OK: Waybar detecta bateria e brilho pelo sysfs\n'

export HOME="$TEST_ROOT/home com espaços"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
export XDG_RUNTIME_DIR="$TEST_ROOT/runtime" WAYLAND_DISPLAY=wayland-test HYPRLAND_INSTANCE_SIGNATURE=test-session XDG_CURRENT_DESKTOP=Hyprland
export STUB_LOG="$TEST_ROOT/calls"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$TEST_ROOT/bin" "$XDG_DATA_HOME/juno-desktop/wallpapers"
chmod 700 "$XDG_RUNTIME_DIR"
cp -R "$ROOT/config" "$XDG_CONFIG_HOME"
cp "$ROOT/assets/desktop/wallpapers/juno-paper.png" "$XDG_DATA_HOME/juno-desktop/wallpapers/juno-paper.png"
cat > "$TEST_ROOT/stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
line="$name"
for argument in "$@"; do line+=" <$argument>"; done
printf '%s\n' "$line" >> "$STUB_LOG"
case "$name" in
    pgrep) exit 1 ;;
    flock) exit 0 ;;
    dbus-update-activation-environment) exit "${STUB_DBUS_EXIT:-0}" ;;
    systemctl) exit "${STUB_SYSTEMD_EXIT:-0}" ;;
    awww) exit 0 ;;
    notify-send) exit 0 ;;
    nohup) exit 0 ;;
    *) exit 99 ;;
esac
STUB
for name in pgrep flock dbus-update-activation-environment systemctl awww notify-send nohup mako waybar awww-daemon hypridle; do
    cp "$TEST_ROOT/stub" "$TEST_ROOT/bin/$name"
    chmod +x "$TEST_ROOT/bin/$name"
done
export PATH="$TEST_ROOT/bin:$PATH"
bash "$ROOT/config/juno/bin/session-start"
for ((attempt=0; attempt<30; attempt++)); do
    if grep -q 'nohup <hypridle>' "$STUB_LOG"; then break; fi
    sleep 0.1
done
grep -q 'dbus-update-activation-environment <--systemd> <WAYLAND_DISPLAY>' "$STUB_LOG"
grep -q 'systemctl <--user> <start> <pipewire.socket> <pipewire-pulse.socket> <wireplumber.service>' "$STUB_LOG"
grep -q 'systemctl <--user> <start> <hyprpolkitagent.service>' "$STUB_LOG"
grep -q 'nohup <mako>' "$STUB_LOG"
grep -q 'nohup <waybar>' "$STUB_LOG"
grep -q 'nohup <awww-daemon>' "$STUB_LOG"
grep -q 'nohup <hypridle>' "$STUB_LOG"
jq -e . "$XDG_RUNTIME_DIR/juno-desktop/waybar-test-session.json" >/dev/null
printf 'OK: inicialização coordena D-Bus, áudio, autenticação e componentes\n'

: > "$STUB_LOG"
export STUB_DBUS_EXIT=1
if bash "$ROOT/config/juno/bin/session-start" > "$TEST_ROOT/out" 2>&1; then
    printf 'Falha D-Bus deveria interromper a inicialização.\n' >&2; exit 1
fi
if grep -q 'systemctl ' "$STUB_LOG"; then
    printf 'Serviços foram iniciados apesar da falha D-Bus.\n' >&2; exit 1
fi
unset STUB_DBUS_EXIT
printf 'OK: falha D-Bus interrompe antes dos serviços dependentes\n'

lock_file="$XDG_RUNTIME_DIR/juno-desktop/start-test-session.lock"
rm "$lock_file"
mkdir "$lock_file"
if bash "$ROOT/config/juno/bin/session-start" > "$TEST_ROOT/out" 2>&1; then
    printf 'Arquivo de lock inválido deveria ser rejeitado.\n' >&2; exit 1
fi
rmdir "$lock_file"
printf 'OK: arquivo de lock não regular rejeitado\n'
printf '5 cenários de sessão passaram (serviços simulados; jq real).\n'
