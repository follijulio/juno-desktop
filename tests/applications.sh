#!/usr/bin/env bash
# Os comandos Flatpak são simulados, sem instalar aplicativos neste computador.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/applications.sh
source "$ROOT/lib/applications.sh"
JUNO_PLATFORM=arch
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
JUNO_STATE="$TEST_ROOT/state"
mkdir "$JUNO_STATE"
CALLS="$TEST_ROOT/calls"
REMOTE_URL=''
REMOTE_OPTIONS=''
INSTALL_STATUS=0
INFO_USER_IDS=''
INFO_SYSTEM_IDS=''
INFO_ORIGIN=flathub
flatpak() {
    printf '%s\n' "$*" >> "$CALLS"
    case $1 in
        remotes)
            [[ -z $REMOTE_URL ]] || printf 'flathub\t%s\t%s\n' "$REMOTE_URL" "$REMOTE_OPTIONS"
            ;;
        remote-add) REMOTE_URL=https://dl.flathub.org/repo/ ;;
        install) return "$INSTALL_STATUS" ;;
        info)
            if [[ $* == *--show-commit* ]]; then
                printf 'spotify-test-commit\n'
            elif [[ $* == *--show-origin* ]]; then
                printf '%s\n' "$INFO_ORIGIN"
            elif [[ $2 == --user ]]; then
                [[ " $INFO_USER_IDS " == *" ${*: -1} "* ]] || return 1
            else
                [[ " $INFO_SYSTEM_IDS " == *" ${*: -1} "* ]] || return 1
            fi
            ;;
        *) return 99 ;;
    esac
    return 0
}
juno_install_spotify >/dev/null
grep -q '^remote-add --user --if-not-exists flathub https://' "$CALLS"
grep -q '^install --user --or-update flathub com.spotify.Client$' "$CALLS"
[[ $(cat "$JUNO_STATE/apps/spotify.commit") == spotify-test-commit ]]
printf 'OK: Spotify instalado por usuário após configurar Flathub\n'
: > "$CALLS"
juno_install_spotify >/dev/null
if grep -q '^remote-add ' "$CALLS"; then exit 1; fi
printf 'OK: repositório oficial existente é reutilizado\n'
REMOTE_URL=https://example.invalid/repo
if (juno_install_spotify) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'endereço diferente' "$TEST_ROOT/error"
printf 'OK: nome flathub com URL diferente é rejeitado\n'
REMOTE_URL=https://dl.flathub.org/repo/
REMOTE_OPTIONS=no-gpg-verify
if (juno_install_spotify) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'assinaturas' "$TEST_ROOT/error"
printf 'OK: repositório sem verificação de assinatura é rejeitado\n'
REMOTE_OPTIONS=''
INSTALL_STATUS=1
if (juno_install_spotify) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'instalação do Spotify falhou' "$TEST_ROOT/error"
printf 'OK: falha Flatpak é reportada antes de aplicar dotfiles\n'

# A real juno_die inside the optional install must stay inside its subshell.
# Files record calls because assignments in the subshell cannot reach this shell.
VSCODE_STATUS=0
juno_install_vscode() {
    printf 'vscode\n' >> "$CALLS"
    return "$VSCODE_STATUS"
}
for INSTALL_STATUS in 1 2; do
    : > "$CALLS"
    juno_install_applications > "$TEST_ROOT/error" 2>&1
    [[ $JUNO_SPOTIFY_SKIPPED == 1 ]]
    grep -q '^vscode$' "$CALLS"
    grep -q 'Continuando com VS Code' "$TEST_ROOT/error"
done
printf 'OK: recusa e falha do Spotify não interrompem VS Code nem o instalador\n'

INSTALL_STATUS=0
: > "$CALLS"
juno_install_applications > "$TEST_ROOT/error" 2>&1
[[ $JUNO_SPOTIFY_SKIPPED == 0 ]]
grep -q '^vscode$' "$CALLS"
if grep -q 'Continuando com VS Code' "$TEST_ROOT/error"; then exit 1; fi
printf 'OK: sucesso do Spotify limpa a indicação de aplicativo ignorado\n'

REMOTE_URL=https://example.invalid/repo
: > "$CALLS"
juno_install_applications > "$TEST_ROOT/error" 2>&1
[[ $JUNO_SPOTIFY_SKIPPED == 1 ]]
grep -q 'endereço diferente' "$TEST_ROOT/error"
grep -q '^vscode$' "$CALLS"
if grep -q '^install ' "$CALLS"; then exit 1; fi
printf 'OK: Flathub inseguro continua rejeitado sem impedir a configuração essencial\n'

REMOTE_URL=https://dl.flathub.org/repo/
VSCODE_STATUS=7
: > "$CALLS"
if juno_install_applications > "$TEST_ROOT/error" 2>&1; then exit 1; else status=$?; fi
[[ $status == 7 ]]
grep -q '^vscode$' "$CALLS"
printf 'OK: falha do VS Code obrigatório continua sendo propagada\n'

VSCODE_STATUS=0
INSTALL_STATUS=0
REMOTE_URL=https://dl.flathub.org/repo/
: > "$CALLS"
juno_install_zorin_app com.valvesoftware.Steam Steam juno-test-absent-command steam >/dev/null
grep -q '^install --user --or-update flathub com.valvesoftware.Steam$' "$CALLS"
[[ -s $JUNO_STATE/apps/steam.commit ]]
printf 'OK: Steam no Zorin é instalado como Flatpak do usuário sem multilib\n'

juno_test_existing_app() { :; }
: > "$CALLS"
juno_install_zorin_app com.discordapp.Discord Discord juno_test_existing_app discord >/dev/null
[[ ! -s $CALLS ]]
printf 'OK: aplicativo nativo existente evita instalação e consultas Flatpak\n'

INFO_SYSTEM_IDS=com.valvesoftware.Steam
: > "$CALLS"
juno_install_zorin_app com.valvesoftware.Steam Steam juno-test-absent-command steam >/dev/null
if grep -q '^install\|^remote-add\|^remotes ' "$CALLS"; then exit 1; fi
printf 'OK: aplicativo Flatpak do sistema não é duplicado no usuário\n'

INFO_SYSTEM_IDS=''
INFO_USER_IDS=com.discordapp.Discord
INFO_ORIGIN=private-origin
REMOTE_URL=https://example.invalid/repo
: > "$CALLS"
juno_install_zorin_app com.discordapp.Discord Discord juno-test-absent-command discord >/dev/null
if grep -q '^install\|^remote-add\|^remotes ' "$CALLS"; then exit 1; fi
printf 'OK: origem de aplicativo existente é preservada sem substituir remotes\n'

INFO_ORIGIN=flathub
: > "$CALLS"
if (juno_install_zorin_app com.discordapp.Discord Discord juno-test-absent-command discord) > "$TEST_ROOT/error" 2>&1; then exit 1; fi
grep -q 'endereço diferente' "$TEST_ROOT/error"
if grep -q '^install ' "$CALLS"; then exit 1; fi
printf 'OK: atualização Zorin recusa Flathub inseguro antes do download\n'

REMOTE_URL=https://dl.flathub.org/repo/
JUNO_PLATFORM=zorin
spotify() { :; }
: > "$CALLS"
juno_install_spotify >/dev/null
[[ ! -s $CALLS ]]
printf 'OK: Spotify nativo do Zorin não recebe instalação Flatpak duplicada\n'

juno_install_zorin_app() {
    printf 'zorin-app %s\n' "$1" >> "$CALLS"
    juno_die 'recusa simulada do aplicativo opcional'
}
: > "$CALLS"
juno_install_applications > "$TEST_ROOT/error" 2>&1
grep -q '^zorin-app com.valvesoftware.Steam$' "$CALLS"
grep -q '^zorin-app com.discordapp.Discord$' "$CALLS"
grep -q '^vscode$' "$CALLS"
grep -q 'Steam não foi instalado' "$TEST_ROOT/error"
grep -q 'Discord não foi instalado' "$TEST_ROOT/error"
printf 'OK: recusa de Steam e Discord no Zorin não interrompe VS Code nem o desktop\n'

: > "$CALLS"
juno_applications_plan > "$TEST_ROOT/plan"
grep -q 'pacote .deb' "$TEST_ROOT/plan"
if grep -q 'pelo pacman\|sudo pacman\|Steam: habilitar' "$TEST_ROOT/plan"; then exit 1; fi
[[ ! -s $CALLS ]]
printf 'OK: plano Zorin informa APT/Flatpak sem executar instalação\n'
printf '18 cenários de aplicativos passaram.\n'
