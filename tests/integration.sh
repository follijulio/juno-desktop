#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export TEST_ROOT ROOT
mkdir -p "$TEST_ROOT/mock-bin"
if ! command -v flock >/dev/null 2>&1; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/flock"
    chmod +x "$TEST_ROOT/mock-bin/flock"
fi
# sync -f does not support the Windows filesystem. Native durability has its own QA.
if [[ $(uname -s) != Linux ]]; then
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mock-bin/sync"
    chmod +x "$TEST_ROOT/mock-bin/sync"
fi
export PATH="$TEST_ROOT/mock-bin:$PATH"

cat > "$TEST_ROOT/harness.sh" <<'HARNESS'
#!/usr/bin/env bash
set -euo pipefail
source "$ROOT/install.sh"
juno_preflight_base() {
    JUNO_HOME=$(realpath -e "$TEST_ROOT/home")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
}
juno_preflight_terminal() { :; }
juno_begin_log() { :; }
fc-cache() { :; }
juno_preflight_base
juno_define_targets
case "$1" in
    pending)
        # A v1 Hyprland journal must recover even with the GNOME installer.
        JUNO_TARGETS=(.config/hypr .config/waybar .config/rofi .config/mako .config/kitty .config/juno .config/xdg-desktop-portal .local/share/fonts/juno .local/share/juno-desktop)
        JUNO_SOURCES=("$ROOT/config/hypr" "$ROOT/config/waybar" "$ROOT/config/rofi" "$ROOT/config/mako" "$ROOT/config/kitty" "$ROOT/config/juno" "$ROOT/config/xdg-desktop-portal" "$ROOT/assets/fonts/spacemono" "$ROOT/assets/desktop")
        txn_lock
        for target in "${JUNO_TARGETS[@]}"; do
            mkdir -p "$JUNO_HOME/$target"
            printf 'original\n' > "$JUNO_HOME/$target/original.txt"
        done
        txn_prepare
        txn_backup
        txn_apply
        # Exit without finalizing: simulates process loss after the directory swaps.
        ;;
    offline)
        juno_preflight_install() { printf 'offline simulado\n' >&2; return 23; }
        juno_main
        ;;
    dry)
        juno_preflight_install() { [[ $1 == readonly ]]; }
        juno_main --dry-run
        ;;
    optional-spotify)
        # Exercise the real orchestration/traps and transaction after Flatpak
        # refuses its runtime. Only external services, downloads and schemas
        # are simulated; the dotfile backup, apply and finalization are real.
        juno_define_targets() {
            JUNO_TARGETS=(.bashrc)
            JUNO_SOURCES=("$TEST_ROOT/new-bashrc")
        }
        printf 'managed bashrc\n' > "$TEST_ROOT/new-bashrc"
        printf 'original\n' > "$TEST_ROOT/mock-settings"
        juno_preflight_install() { :; }
        juno_validate_resources() { :; }
        juno_validate_gallery() { :; }
        juno_install_packages() { :; }
        juno_validate_gnome() { :; }
        flatpak() {
            case $1 in
                remotes) printf 'flathub\thttps://dl.flathub.org/repo/\t\n' ;;
                install) return 1 ;;
                *) return 99 ;;
            esac
        }
        juno_install_vscode() { printf 'vscode\n' >> "$TEST_ROOT/application-calls"; }
        juno_install_posh() { printf 'posh\n' >> "$TEST_ROOT/application-calls"; }
        juno_gsettings_snapshot() { cp -- "$TEST_ROOT/mock-settings" "$1"; }
        juno_gsettings_desired() { printf 'Roboto\n' > "$1"; }
        juno_gsettings_validate() { [[ -f $1 ]]; }
        juno_gsettings_verify() { cmp -s -- "$TEST_ROOT/mock-settings" "$1"; }
        juno_gsettings_restore() { cp -- "$1" "$TEST_ROOT/mock-settings"; }
        juno_stage_gallery() { :; }
        juno_stage_terminal() { :; }
        juno_validate_staged() { :; }
        juno_validate_installed_fonts() { :; }
        juno_configure_gdm() { printf 'gdm\n' >> "$TEST_ROOT/application-calls"; }
        juno_main
        ;;
esac
HARNESS
mkdir "$TEST_ROOT/home"
bash "$TEST_ROOT/harness.sh" dry > "$TEST_ROOT/dry.log"
[[ -z $(find "$TEST_ROOT/home" -mindepth 1 -print -quit) ]] || { printf 'Simulação gravou arquivos.\n' >&2; exit 1; }
printf 'OK: dry-run integrado sem gravações\n'
bash "$TEST_ROOT/harness.sh" pending > "$TEST_ROOT/pending.log"
[[ -f "$TEST_ROOT/home/.local/state/juno-desktop/pending.tsv" ]]
if bash "$TEST_ROOT/harness.sh" offline > "$TEST_ROOT/offline.log" 2>&1; then
    printf 'Esperava falha de conexão.\n' >&2
    exit 1
fi
[[ ! -f "$TEST_ROOT/home/.local/state/juno-desktop/pending.tsv" ]]
grep -q 'Transação interrompida recuperada' "$TEST_ROOT/offline.log"
grep -q 'offline simulado' "$TEST_ROOT/offline.log"
for target in .config/hypr .config/waybar .config/rofi .config/mako .config/kitty .config/juno .config/xdg-desktop-portal .local/share/fonts/juno .local/share/juno-desktop; do
    [[ $(cat "$TEST_ROOT/home/$target/original.txt") == original ]]
done
printf 'OK: recuperação integrada ocorre antes de verificar rede\n'
bash "$TEST_ROOT/harness.sh" optional-spotify > "$TEST_ROOT/optional-spotify.log" 2>&1
[[ $(cat "$TEST_ROOT/home/.bashrc") == 'managed bashrc' ]]
[[ $(cat "$TEST_ROOT/mock-settings") == Roboto ]]
[[ $(cat "$TEST_ROOT/application-calls") == $'vscode\nposh\ngdm' ]]
[[ ! -f "$TEST_ROOT/home/.local/state/juno-desktop/pending.tsv" ]]
grep -q 'Ambiente Juno configurado com sucesso' "$TEST_ROOT/optional-spotify.log"
grep -q 'Spotify não foi instalado ou atualizado nesta execução' "$TEST_ROOT/optional-spotify.log"
if grep -q 'Operação interrompida' "$TEST_ROOT/optional-spotify.log"; then
    printf 'Falha opcional acionou a recuperação do instalador.\n' >&2
    exit 1
fi
printf 'OK: falha opcional do Spotify permite aplicar e finalizar arquivos e preferências\n'
printf '3 cenários de integração passaram.\n'
