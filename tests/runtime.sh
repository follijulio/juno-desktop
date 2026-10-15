#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_TEMP_ROOT=$(cd -- "${TMPDIR:-/tmp}" && pwd)
TEST_SANDBOX=$(mktemp -d "$TEST_TEMP_ROOT/juno-runtime-test.XXXXXX")
cleanup() {
    case "$TEST_SANDBOX" in
        "$TEST_TEMP_ROOT"/juno-runtime-test.*) rm -rf -- "$TEST_SANDBOX" ;;
        *) printf 'Diretório de teste inesperado; limpeza recusada.\n' >&2 ;;
    esac
}
trap cleanup EXIT

export HOME="$TEST_SANDBOX/home with spaces"
export XDG_CONFIG_HOME="$HOME/config with spaces"
export XDG_DATA_HOME="$HOME/data"
export XDG_STATE_HOME="$HOME/state"
export XDG_RUNTIME_DIR="$TEST_SANDBOX/runtime"
export WAYLAND_DISPLAY=wayland-juno-test
export HYPRLAND_INSTANCE_SIGNATURE=juno-test-123
export XDG_CURRENT_DESKTOP=Hyprland
export STUB_LOG="$TEST_SANDBOX/commands.log"
export STUB_ROFI_STATE="$TEST_SANDBOX/rofi-state"
export STUB_CLIPBOARD="$TEST_SANDBOX/clipboard"
export STUB_PICTURES="$HOME/Imagens com espaços"
mkdir -p -- "$TEST_SANDBOX/bin" "$HOME" "$XDG_RUNTIME_DIR"
chmod 700 -- "$XDG_RUNTIME_DIR"
export PATH="$TEST_SANDBOX/bin:$PATH"

cat > "$TEST_SANDBOX/command-stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
{ printf '%s' "$name"; printf ' <%s>' "$@"; printf '\n'; } >> "$STUB_LOG"
case "$name" in
    slurp) [[ ${STUB_SLURP_EXIT:-0} == 0 ]] || exit "$STUB_SLURP_EXIT"; printf '10,20 300x400\n' ;;
    grim) [[ ${STUB_GRIM_EXIT:-0} == 0 ]] || exit "$STUB_GRIM_EXIT"; printf 'PNG-FIXTURE' > "${@: -1}" ;;
    wl-copy) [[ ${STUB_COPY_EXIT:-0} == 0 ]] || exit "$STUB_COPY_EXIT"; cat > "$STUB_CLIPBOARD" ;;
    xdg-user-dir) printf '%s\n' "$STUB_PICTURES" ;;
    rofi)
        step=0
        [[ ! -f $STUB_ROFI_STATE ]] || step=$(< "$STUB_ROFI_STATE")
        printf '%s' "$((step + 1))" > "$STUB_ROFI_STATE"
        [[ ${STUB_ROFI_EXIT:-0} == 0 ]] || exit "$STUB_ROFI_EXIT"
        if [[ $step == 0 ]]; then printf '%s\n' "${STUB_ROFI_FIRST:-}"; else printf '%s\n' "${STUB_ROFI_SECOND:-}"; fi
        ;;
    systemctl) exit "${STUB_SYSTEMCTL_EXIT:-0}" ;;
    hyprctl) exit "${STUB_HYPRCTL_EXIT:-0}" ;;
    flock) exit "${STUB_FLOCK_EXIT:-0}" ;;
    pgrep) exit 1 ;;
    hyprlock) exit "${STUB_HYPRLOCK_EXIT:-0}" ;;
    wpctl)
        [[ ${STUB_WPCTL_EXIT:-0} == 0 ]] || exit "$STUB_WPCTL_EXIT"
        [[ ${1:-} != get-volume ]] || printf 'Volume: 0.55\n'
        ;;
    brightnessctl)
        [[ ${STUB_BRIGHTNESS_EXIT:-0} == 0 ]] || exit "$STUB_BRIGHTNESS_EXIT"
        printf 'screen,backlight,55,55%%,100\n'
        ;;
    notify-send) : ;;
    *) printf 'Comando inesperado: %s\n' "$name" >&2; exit 99 ;;
esac
STUB
for command in slurp grim wl-copy xdg-user-dir rofi systemctl hyprctl flock pgrep hyprlock wpctl brightnessctl notify-send; do
    cp -- "$TEST_SANDBOX/command-stub" "$TEST_SANDBOX/bin/$command"
    chmod +x -- "$TEST_SANDBOX/bin/$command"
done

tests=0
reset_stubs() {
    : > "$STUB_LOG"
    rm -f -- "$STUB_ROFI_STATE" "$STUB_CLIPBOARD"
    unset STUB_SLURP_EXIT STUB_GRIM_EXIT STUB_COPY_EXIT STUB_ROFI_EXIT STUB_ROFI_FIRST STUB_ROFI_SECOND
    unset STUB_SYSTEMCTL_EXIT STUB_HYPRCTL_EXIT STUB_FLOCK_EXIT STUB_HYPRLOCK_EXIT STUB_WPCTL_EXIT STUB_BRIGHTNESS_EXIT
}
run_expect() {
    local expected=$1 status=0
    shift
    "$@" > "$TEST_SANDBOX/stdout" 2> "$TEST_SANDBOX/stderr" || status=$?
    if [[ $status != "$expected" ]]; then
        cat -- "$TEST_SANDBOX/stderr" >&2
        printf 'Status esperado: %s; recebido: %s\n' "$expected" "$status" >&2
        exit 1
    fi
    tests=$((tests + 1))
}
assert_log() { grep -F -- "$1" "$STUB_LOG" > /dev/null; }
assert_no_log() { if grep -F -- "$1" "$STUB_LOG" > /dev/null; then printf 'Comando não autorizado: %s\n' "$1" >&2; exit 1; fi; }
runtime_script() { bash -- "$PROJECT_ROOT/config/juno/bin/$1" "${@:2}"; }

reset_stubs
export STUB_SLURP_EXIT=1
run_expect 0 runtime_script screenshot save
assert_no_log 'grim <'
[[ ! -d $STUB_PICTURES/Juno ]]

reset_stubs
run_expect 0 runtime_script screenshot save
saved_file=$(< "$TEST_SANDBOX/stdout")
[[ -f $saved_file && $saved_file == "$STUB_PICTURES/Juno/"*.png ]]
[[ $(< "$saved_file") == PNG-FIXTURE ]]
assert_log 'grim <-g> <10,20 300x400>'

reset_stubs
run_expect 0 runtime_script screenshot full
full_file=$(< "$TEST_SANDBOX/stdout")
[[ -f $full_file && $full_file != "$saved_file" ]]
assert_no_log 'slurp <'

reset_stubs
run_expect 0 runtime_script screenshot copy
[[ $(< "$STUB_CLIPBOARD") == PNG-FIXTURE ]]
[[ -z $(find "$XDG_RUNTIME_DIR" -name '*.png' -print) ]]
assert_log 'wl-copy <--type> <image/png>'

reset_stubs
export STUB_GRIM_EXIT=2
before_count=$(find "$STUB_PICTURES/Juno" -type f | wc -l)
run_expect 1 runtime_script screenshot save
after_count=$(find "$STUB_PICTURES/Juno" -type f | wc -l)
[[ $before_count == "$after_count" ]]
assert_log 'Captura não concluída'

reset_stubs
export STUB_COPY_EXIT=1
run_expect 1 runtime_script screenshot copy
[[ -z $(find "$XDG_RUNTIME_DIR" -name '*.png' -print) ]]

reset_stubs
run_expect 2 runtime_script screenshot unexpected
assert_no_log 'grim <'

reset_stubs
# This literal payload must never expand or execute.
# shellcheck disable=SC2016
export STUB_ROFI_FIRST='$(touch "$HOME/injected")'
run_expect 0 runtime_script power-menu
assert_no_log 'systemctl <'
assert_no_log 'hyprctl <'
[[ ! -e $HOME/injected ]]

reset_stubs
export STUB_ROFI_FIRST=Reiniciar STUB_ROFI_SECOND=Cancelar
run_expect 0 runtime_script power-menu
assert_no_log 'systemctl <'

reset_stubs
export STUB_ROFI_FIRST=Reiniciar STUB_ROFI_SECOND=Confirmar
run_expect 0 runtime_script power-menu
assert_log 'systemctl <reboot>'

reset_stubs
export STUB_ROFI_FIRST='Encerrar sessão' STUB_ROFI_SECOND=Confirmar
run_expect 0 runtime_script power-menu
assert_log 'hyprctl <dispatch> <hl.dsp.exit()>'

reset_stubs
export STUB_ROFI_FIRST=Desligar STUB_ROFI_SECOND=Confirmar STUB_SYSTEMCTL_EXIT=1
run_expect 1 runtime_script power-menu
assert_log 'Ação não concluída'

reset_stubs
export STUB_FLOCK_EXIT=1
run_expect 0 runtime_script lock
assert_no_log 'hyprlock <'

reset_stubs
export STUB_HYPRLOCK_EXIT=1
run_expect 1 runtime_script lock
assert_log 'Bloqueio não iniciado'
assert_log "hyprlock <--no-fade-in> <--config> <$XDG_CONFIG_HOME/hypr/hyprlock.conf>"

reset_stubs
run_expect 0 runtime_script audio up
assert_log 'wpctl <set-volume> <-l> <1> <@DEFAULT_AUDIO_SINK@> <5%+>'
assert_log '55%.'

reset_stubs
export STUB_WPCTL_EXIT=1
run_expect 1 runtime_script audio mic-mute
assert_log 'Áudio indisponível'

reset_stubs
export STUB_BRIGHTNESS_EXIT=1
run_expect 1 runtime_script brightness down
assert_log 'Brilho indisponível'

reset_stubs
run_expect 0 runtime_script brightness up
assert_log 'brightnessctl <--class=backlight> <--machine-readable> <--min-value=1> <set> <5%+>'

printf 'Runtime Juno: %s cenários passaram.\n' "$tests"
