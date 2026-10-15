#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v jq >/dev/null || { printf 'jq necessário para testar a galeria.\n' >&2; exit 1; }
TEST_SANDBOX=$(mktemp -d)
trap 'rm -rf -- "$TEST_SANDBOX"' EXIT
export HOME="$TEST_SANDBOX/home with spaces"
export XDG_CONFIG_HOME="$HOME/config with spaces" XDG_DATA_HOME="$HOME/data" XDG_STATE_HOME="$HOME/state"
export XDG_RUNTIME_DIR="$TEST_SANDBOX/runtime" WAYLAND_DISPLAY=wayland-juno-test HYPRLAND_INSTANCE_SIGNATURE=wallpaper-test
export STUB_LOG="$TEST_SANDBOX/calls" STUB_LOCK_CONFIG="$TEST_SANDBOX/lock.conf"
gallery=$XDG_DATA_HOME/juno-desktop/wallpapers/gallery
state=$XDG_STATE_HOME/juno-desktop/wallpaper/current
mkdir -p -- "$TEST_SANDBOX/bin" "$HOME" "$XDG_RUNTIME_DIR" "$gallery" "$XDG_CONFIG_HOME/hypr"
chmod 700 -- "$XDG_RUNTIME_DIR"
cp -- "$PROJECT_ROOT/config/hypr/hyprlock.conf" "$XDG_CONFIG_HOME/hypr/hyprlock.conf"
printf 'first-image\n' > "$gallery/first.jpg"
printf 'second-image\n' > "$gallery/second.png"
cat > "$gallery/catalog.json" <<'JSON'
{"version":1,"default":"first","wallpapers":[{"id":"first","name":"Primeira imagem","file":"first.jpg"},{"id":"second","name":"Segunda imagem","file":"second.png"}]}
JSON
cp -- "$gallery/catalog.json" "$TEST_SANDBOX/catalog.json"
cat > "$TEST_SANDBOX/stub" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
{ printf '%s' "$name"; printf ' <%s>' "$@"; printf '\n'; } >> "$STUB_LOG"
case "$name" in
    awww)
        case "${1:-}" in
            query) exit "${STUB_QUERY_EXIT:-0}" ;;
            img) exit "${STUB_IMAGE_EXIT:-0}" ;;
            *) exit 99 ;;
        esac
        ;;
    rofi) cat >/dev/null; [[ ${STUB_ROFI_EXIT:-0} == 0 ]] || exit "$STUB_ROFI_EXIT"; printf '%s\n' "${STUB_INDEX:-0}" ;;
    hyprlock) cp -- "${@: -1}" "$STUB_LOCK_CONFIG" ;;
    flock|notify-send) : ;;
    pgrep) exit 1 ;;
    *) exit 99 ;;
esac
STUB
for name in awww rofi hyprlock flock pgrep notify-send; do
    cp -- "$TEST_SANDBOX/stub" "$TEST_SANDBOX/bin/$name"
    chmod +x -- "$TEST_SANDBOX/bin/$name"
done
export PATH="$TEST_SANDBOX/bin:$PATH"
tests=0
run_expect() {
    local expected=$1 status=0
    shift
    : > "$STUB_LOG"
    "$@" > "$TEST_SANDBOX/out" 2> "$TEST_SANDBOX/err" || status=$?
    if [[ $status != "$expected" ]]; then
        cat -- "$TEST_SANDBOX/err" >&2
        printf 'Status esperado %s, recebido %s.\n' "$expected" "$status" >&2
        exit 1
    fi
    tests=$((tests + 1))
}
wallpaper() { bash -- "$PROJECT_ROOT/config/juno/bin/wallpaper" "$@"; }
assert_no_apply() { ! grep -F 'awww <img>' "$STUB_LOG" >/dev/null; }

run_expect 0 wallpaper list
grep -F 'Primeira imagem' "$TEST_SANDBOX/out" >/dev/null
[[ ! -e $state ]]

run_expect 0 wallpaper apply
[[ $(< "$state") == first ]]
grep -F "awww <img> <--transition-type> <none> <$gallery/first.jpg>" "$STUB_LOG" >/dev/null

run_expect 0 wallpaper set second
[[ $(< "$state") == second ]]

export STUB_INDEX=0
run_expect 0 wallpaper select
[[ $(< "$state") == first ]]
grep -F '<-no-custom> <-format> <i>' "$STUB_LOG" >/dev/null

export STUB_IMAGE_EXIT=1
run_expect 1 wallpaper set second
[[ $(< "$state") == first ]]
unset STUB_IMAGE_EXIT

export STUB_QUERY_EXIT=1
run_expect 1 wallpaper set second
assert_no_apply
[[ $(< "$state") == first ]]
unset STUB_QUERY_EXIT

export STUB_ROFI_EXIT=1
run_expect 0 wallpaper select
assert_no_apply
unset STUB_ROFI_EXIT

# shellcheck disable=SC2016
export STUB_INDEX='$(touch "$HOME/injected")'
run_expect 0 wallpaper select
assert_no_apply
[[ ! -e $HOME/injected && $(< "$state") == first ]]

run_expect 1 wallpaper set ../../outside.jpg
assert_no_apply

jq '.wallpapers[0].file = "../../outside.jpg"' "$TEST_SANDBOX/catalog.json" > "$gallery/catalog.json"
run_expect 1 wallpaper apply
assert_no_apply
cp -- "$TEST_SANDBOX/catalog.json" "$gallery/catalog.json"

# MSYS may emulate symlinks with copies. Run this assertion where ln makes links.
printf 'outside\n' > "$TEST_SANDBOX/outside.jpg"
mv -- "$gallery/first.jpg" "$TEST_SANDBOX/first.jpg"
ln -s -- "$TEST_SANDBOX/outside.jpg" "$gallery/first.jpg"
if [[ -L $gallery/first.jpg ]]; then
    run_expect 1 wallpaper set first
    assert_no_apply
else
    printf 'PENDENTE Linux: rejeição de imagem symlink (MSYS usa cópia).\n'
fi
rm -f -- "$gallery/first.jpg"
mv -- "$TEST_SANDBOX/first.jpg" "$gallery/first.jpg"

mv -- "$state" "$TEST_SANDBOX/current"
ln -s -- "$TEST_SANDBOX/current" "$state"
if [[ -L $state ]]; then
    run_expect 1 wallpaper set second
    assert_no_apply
    [[ $(< "$TEST_SANDBOX/current") == first ]]
else
    printf 'PENDENTE Linux: rejeição de estado symlink (MSYS usa cópia).\n'
fi
rm -f -- "$state"
mv -- "$TEST_SANDBOX/current" "$state"

printf '../invalid\n' > "$state"
run_expect 0 wallpaper current
[[ $(< "$TEST_SANDBOX/out") == first ]]

jq '.wallpapers[0].name = "Fake\nsecond line"' "$TEST_SANDBOX/catalog.json" > "$gallery/catalog.json"
run_expect 1 wallpaper list
assert_no_apply
cp -- "$TEST_SANDBOX/catalog.json" "$gallery/catalog.json"

run_expect 0 wallpaper set second
run_expect 0 bash -- "$PROJECT_ROOT/config/juno/bin/lock"
grep -Fx "    path = $gallery/second.png" "$STUB_LOCK_CONFIG" >/dev/null
[[ ! -e $XDG_RUNTIME_DIR/juno-desktop/hyprlock-wallpaper-test.conf ]]

rm -f -- "$gallery/second.png"
run_expect 0 bash -- "$PROJECT_ROOT/config/juno/bin/lock"
grep -Fx "    path = $gallery/first.jpg" "$STUB_LOCK_CONFIG" >/dev/null

mv -- "$gallery/catalog.json" "$TEST_SANDBOX/missing-catalog.json"
run_expect 0 bash -- "$PROJECT_ROOT/config/juno/bin/lock"
grep -Fx '    path = ' "$STUB_LOCK_CONFIG" >/dev/null
mv -- "$TEST_SANDBOX/missing-catalog.json" "$gallery/catalog.json"

# A legal filesystem name must not turn into a Hyprlang directive.
unsafe_data=$HOME/'data#path = screenshot'
mkdir -p -- "$unsafe_data/juno-desktop/wallpapers"
cp -R -- "$gallery" "$unsafe_data/juno-desktop/wallpapers/gallery"
export XDG_DATA_HOME=$unsafe_data
run_expect 0 bash -- "$PROJECT_ROOT/config/juno/bin/lock"
grep -Fx '    path = ' "$STUB_LOCK_CONFIG" >/dev/null
[[ ! -e $HOME/injected ]]

printf 'Galeria e bloqueio Juno: %s cenários passaram (jq real, comandos de sessão simulados).\n' "$tests"
