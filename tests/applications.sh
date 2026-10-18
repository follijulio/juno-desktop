#!/usr/bin/env bash
# Os comandos Flatpak são simulados, sem instalar aplicativos neste computador.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/applications.sh
source "$ROOT/lib/applications.sh"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
JUNO_STATE="$TEST_ROOT/state"
mkdir "$JUNO_STATE"
CALLS="$TEST_ROOT/calls"
REMOTE_URL=''
REMOTE_OPTIONS=''
INSTALL_STATUS=0
flatpak() {
    printf '%s\n' "$*" >> "$CALLS"
    case $1 in
        remotes)
            [[ -z $REMOTE_URL ]] || printf 'flathub\t%s\t%s\n' "$REMOTE_URL" "$REMOTE_OPTIONS"
            ;;
        remote-add) REMOTE_URL=https://dl.flathub.org/repo/ ;;
        install) return "$INSTALL_STATUS" ;;
        info) printf 'spotify-test-commit\n' ;;
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
printf '10 cenários de aplicativos passaram.\n'
