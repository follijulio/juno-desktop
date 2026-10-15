#!/usr/bin/env bash
# Os mocks são chamados indiretamente pelos módulos, inclusive pelo mock de sudo.
# shellcheck disable=SC2329,SC2032
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/preflight.sh
source "$ROOT/lib/preflight.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT/lib/packages.sh"
# shellcheck source=../lib/validate.sh
source "$ROOT/lib/validate.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
passed=0
ok() { passed=$((passed + 1)); printf 'OK: %s\n' "$1"; }
expect_failure() {
    if ( "$@" ) >"$TEST_ROOT/error.log" 2>&1; then
        printf 'FALHOU: erro esperado em %s\n' "$*" >&2
        exit 1
    fi
}

Hyprland() { printf '%s\n' "$TEST_VERSION"; }
TEST_VERSION='Hyprland v0.56.2 built from tag'
juno_validate_hyprland_version
ok 'Hyprland 0.56.x aceito'
for TEST_VERSION in 'Hyprland v0.57.0' 'Hyprland v0.55.4' 'Hyprland v10.56.2' 'erro: pacote indisponível'; do
    expect_failure juno_validate_hyprland_version
done
ok 'versões antigas, futuras e saídas inválidas rejeitadas'

HYPRLAND_INSTANCE_SIGNATURE=test-instance
juno_has_hyprland_session
unset HYPRLAND_INSTANCE_SIGNATURE
ok 'sessão ativa identificada pelo ambiente'

curl() { return 22; }
sudo() { return 0; }
pacman() { return 0; }
expect_failure juno_preflight_install readonly
grep -q 'HTTPS' "$TEST_ROOT/error.log"
ok 'ausência de HTTPS interrompe a instalação'
unset -f curl

JUNO_HOME="$TEST_ROOT/home com espacos"
JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
mkdir -p -- "$JUNO_STATE"
PACMAN_CALLS="$TEST_ROOT/pacman.calls"
pacman() {
    if [[ ${1:-} == -Q ]]; then
        [[ $# -eq 1 ]] && printf 'base 1.0\n'
        [[ $# -eq 1 ]] && return 0
        return 1
    fi
    printf '%s\n' "$*" >> "$PACMAN_CALLS"
    return 37
}
sudo() {
    if [[ ${1:-} == -v ]]; then return 0; fi
    "$@"
}
juno_enable_multilib() { :; }
expect_failure juno_install_packages
grep -q -- '-Syu --needed -- hyprland' "$PACMAN_CALLS"
[[ -f $(find "$JUNO_STATE/packages" -name '*.before.txt' -print -quit) ]]
[[ -f $(find "$JUNO_STATE/packages" -name '*.after.txt' -print -quit) ]]
ok 'falha do pacman preserva snapshots e usa atualização completa'

JUNO_ROOT="$ROOT"
juno_define_targets
juno_validate_resources >/dev/null
ok 'integridade dos recursos distribuídos confirmada'

mkdir -p "$TEST_ROOT/corrupt/fonts"
cp -R "$ROOT/assets/fonts/spacemono" "$TEST_ROOT/corrupt/fonts/spacemono"
printf 'corrompido' >> "$TEST_ROOT/corrupt/fonts/spacemono/SpaceMono-Regular.ttf"
mkdir -p "$TEST_ROOT/corrupt/assets"
mv "$TEST_ROOT/corrupt/fonts" "$TEST_ROOT/corrupt/assets/fonts"
JUNO_ROOT="$TEST_ROOT/corrupt"
# Lido pela função do módulo validate.sh.
# shellcheck disable=SC2034
JUNO_SOURCES=("$JUNO_ROOT/assets/fonts/spacemono")
expect_failure juno_validate_resources
grep -q 'integridade' "$TEST_ROOT/error.log"
ok 'fonte adulterada rejeitada'

JUNO_ROOT="$TEST_ROOT/corrupt-wallpaper"
mkdir -p "$JUNO_ROOT"
cp -R "$ROOT/assets" "$JUNO_ROOT/assets"
JUNO_SOURCES=("$JUNO_ROOT/assets/fonts/spacemono" "$JUNO_ROOT/assets/desktop")
printf 'corrompido' >> "$JUNO_ROOT/assets/desktop/wallpapers/juno-paper.png"
expect_failure juno_validate_resources
grep -q 'integridade do wallpaper' "$TEST_ROOT/error.log"
ok 'wallpaper adulterado rejeitado antes da aplicação'

if [[ $(uname -s) != Linux || ! -f /etc/arch-release ]]; then
    expect_failure bash "$ROOT/install.sh" --dry-run
    grep -q 'exige Arch Linux' "$TEST_ROOT/error.log"
    ok 'plataforma real incompatível rejeitada sem alterações'
fi
printf '%s cenários do instalador passaram.\n' "$passed"
