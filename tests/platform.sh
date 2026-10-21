#!/usr/bin/env bash
# No package manager, privilege escalation or host services are executed.
# shellcheck disable=SC2329,SC2032,SC2016
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/platform.sh
source "$ROOT/lib/platform.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT/lib/packages.sh"
# shellcheck source=../lib/multilib.sh
source "$ROOT/lib/multilib.sh"
# shellcheck source=../lib/preflight.sh
source "$ROOT/lib/preflight.sh"
# shellcheck source=../lib/gnome.sh
source "$ROOT/lib/gnome.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
CALLS="$TEST_ROOT/calls"
MISSING="$TEST_ROOT/missing"
passed=0
ok() { passed=$((passed + 1)); printf 'OK: %s\n' "$1"; }
expect_failure() {
    if ( "$@" ) > "$TEST_ROOT/error.log" 2>&1; then
        printf 'FALHOU: erro esperado em %s\n' "$*" >&2
        exit 1
    fi
}
fixture() { printf '%s\n' "$@" > "$TEST_ROOT/os-release"; }

fixture 'ID=arch' 'PRETTY_NAME="Arch Linux"'
juno_detect_platform "$TEST_ROOT/os-release"
[[ $JUNO_PLATFORM == arch && -z $JUNO_ZORIN_VERSION && -z $JUNO_UBUNTU_VERSION ]]
[[ $(juno_gdm_service) == gdm.service ]]
juno_set_packages
[[ " ${JUNO_PACKAGES[*]} " == *' gdm '* && " ${JUNO_PACKAGES[*]} " == *' ttf-jetbrains-mono-nerd '* ]]
ok 'Arch preserva os pacotes e o serviço GDM existentes'

fixture 'ID="zorin"' "VERSION_ID='18.1'" 'VERSION_CODENAME=noble' 'UBUNTU_CODENAME="noble"'
juno_detect_platform "$TEST_ROOT/os-release"
[[ $JUNO_PLATFORM == zorin && $JUNO_ZORIN_VERSION == 18.1 && $JUNO_UBUNTU_VERSION == 24.04 ]]
[[ $(juno_gdm_service) == gdm3.service && $(juno_platform_network_url) == https://zorin.com/ ]]
juno_set_packages
[[ " ${JUNO_PACKAGES[*]} " == *' fonts-jetbrains-mono '* && " ${JUNO_PACKAGES[*]} " == *' python3-gi '* ]]
for package in gdm gdm3 gnome-shell gnome-session pipewire pipewire-pulse pulseaudio \
    steam discord firefox ttf-jetbrains-mono-nerd uv; do
    [[ " ${JUNO_PACKAGES[*]} " != *" $package "* ]]
done
ok 'Zorin 18.1 usa nomes APT sem substituir sessão, login, navegador ou áudio'

fixture 'ID=zorin' 'VERSION_ID=18' 'UBUNTU_CODENAME=noble'
juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=zorin' 'VERSION_ID=17.3' 'UBUNTU_CODENAME=jammy'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=zorin' 'VERSION_ID=19' 'UBUNTU_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=zorin' 'VERSION_ID=18' 'UBUNTU_CODENAME=jammy'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=ubuntu' 'VERSION_ID=24.04' 'VERSION_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=endeavouros' 'ID_LIKE=arch'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
ok 'outras versões, bases e distribuições são rejeitadas antes de alterações'

fixture 'ID=zorin' 'ID=arch' 'VERSION_ID=18' 'UBUNTU_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID=zorin' 'VERSION_ID=18' 'VERSION_CODENAME=jammy' 'UBUNTU_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
fixture 'ID="zorin' 'VERSION_ID=18' 'UBUNTU_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
ok 'identificadores duplicados, aspas incompletas e bases divergentes são rejeitados'

fixture 'ID=zorin' "VERSION_ID=\$(touch \"$TEST_ROOT/executed\")" 'UBUNTU_CODENAME=noble'
expect_failure juno_detect_platform "$TEST_ROOT/os-release"
[[ ! -e $TEST_ROOT/executed ]]
fixture 'ID=zorin' 'VERSION_ID=18' 'UBUNTU_CODENAME=noble' "UNUSED=\$(touch \"$TEST_ROOT/executed\")"
juno_detect_platform "$TEST_ROOT/os-release"
[[ ! -e $TEST_ROOT/executed ]]
ok 'os-release é lido como dados e nunca executa substituição de comandos'

sudo() {
    printf 'sudo %s\n' "$*" >> "$CALLS"
    [[ $1 != -v ]] || return 0
    "$@"
}
dpkg-query() {
    if [[ $# == 2 && $1 == -W ]]; then
        printf 'kitty\t0\tinstalled\n'
        return 0
    fi
    [[ $# == 4 && $1 == -W && $2 == '-f=${Architecture}\t${Status}\n' && $3 == -- ]] || return 99
    if grep -Fxq -- "$4" "$MISSING"; then return 1; fi
    printf 'amd64\tinstall ok installed\n'
}
apt-get() {
    printf 'apt-get %s\n' "$*" >> "$CALLS"
    case $1 in
        update) [[ $APT_UPDATE_FAIL == no ]] ;;
        install)
            [[ $2 == --no-upgrade && $3 == --no-remove && $4 == -- ]] || return 99
            [[ $APT_INSTALL_FAIL == no ]] || return 28
            : > "$MISSING"
            ;;
        *) return 99 ;;
    esac
}
apt-cache() {
    [[ $1 == policy && $# == 2 ]] || return 99
    if [[ $APT_CANDIDATE == yes ]]; then printf '  Candidate: 1.0\n'; else printf '  Candidate: (none)\n'; fi
}
gnome-shell() { return 0; }
gsettings() { return 0; }
dbus-run-session() { return 0; }
fc-cache() { return 0; }
fc-match() { return 0; }
fc-scan() { return 0; }
reset_packages() {
    JUNO_STATE="$TEST_ROOT/state-$passed"
    mkdir -p -- "$JUNO_STATE"
    chmod 700 -- "$JUNO_STATE"
    : > "$CALLS"
    : > "$MISSING"
    APT_UPDATE_FAIL=no; APT_INSTALL_FAIL=no; APT_CANDIDATE=yes
}

reset_packages
juno_install_packages > "$TEST_ROOT/output"
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages ]]
ok 'dependências presentes não provocam sudo, atualização de índices ou reinstalação'

(
    dpkg-query() { printf 'i386\tinstall ok installed\n'; }
    if _juno_dpkg_installed kitty; then exit 1; fi
    dpkg-query() { printf 'i386\tinstall ok installed\namd64\tdeinstall ok config-files\n'; }
    if _juno_dpkg_installed kitty; then exit 1; fi
    dpkg-query() { printf 'i386\tinstall ok installed\namd64\tinstall ok installed\n'; }
    _juno_dpkg_installed kitty
    dpkg-query() { printf 'all\tinstall ok installed\n'; }
    _juno_dpkg_installed fonts-roboto
)
ok 'inventário diferencia dependências nativas, pacotes independentes e bibliotecas somente i386'

reset_packages
printf 'kitty\nfonts-jetbrains-mono\n' > "$MISSING"
juno_install_packages > "$TEST_ROOT/output"
grep -Fx 'apt-get update' "$CALLS" >/dev/null
grep -Fx 'apt-get install --no-upgrade --no-remove -- kitty fonts-jetbrains-mono' "$CALLS" >/dev/null
[[ $(find "$JUNO_STATE/packages" -name '*.before.txt' | wc -l) == 1 ]]
[[ $(find "$JUNO_STATE/packages" -name '*.after.txt' | wc -l) == 1 ]]
ok 'APT recebe somente pacotes ausentes, sem upgrades explícitos ou remoções, e guarda inventários'

reset_packages
printf 'xdg-desktop-portal-gnome\n' > "$MISSING"
juno_install_packages > "$TEST_ROOT/output"
grep -Fx 'apt-get install --no-upgrade --no-remove -- xdg-desktop-portal-gnome' "$CALLS" >/dev/null
ok 'portal GNOME ausente é complementado sem rejeitar uma sessão GNOME existente'

reset_packages
printf 'gnome-shell\n' > "$MISSING"
expect_failure juno_install_packages
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages ]]
grep -q 'Lite/XFCE' "$TEST_ROOT/error.log"
ok 'ausência do GNOME rejeita Lite antes de sudo ou criação de estado de pacotes'

reset_packages
printf 'kitty\n' > "$MISSING"
APT_UPDATE_FAIL=yes
expect_failure juno_install_packages
if grep -q '^apt-get install' "$CALLS"; then exit 1; fi
ok 'falha de índices interrompe antes de instalar dependências'

reset_packages
printf 'kitty\n' > "$MISSING"
APT_CANDIDATE=no
expect_failure juno_install_packages
if grep -q '^apt-get install' "$CALLS"; then exit 1; fi
grep -q 'Nenhum repositório foi adicionado' "$TEST_ROOT/error.log"
ok 'pacote indisponível preserva repositórios e impede substituição de dotfiles'

reset_packages
printf 'kitty\n' > "$MISSING"
APT_INSTALL_FAIL=yes
expect_failure juno_install_packages
[[ $(find "$JUNO_STATE/packages" -name '*.after.txt' | wc -l) == 1 ]]
grep -q 'código 28' "$TEST_ROOT/error.log"
ok 'falha APT mantém inventário e registra o código original'

reset_packages
juno_packages_plan > "$TEST_ROOT/plan"
juno_multilib_plan >> "$TEST_ROOT/plan"
juno_enable_multilib >> "$TEST_ROOT/plan"
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages ]]
if grep -q 'pacman\|add-architecture' "$TEST_ROOT/plan"; then exit 1; fi
ok 'plano Zorin e multilib não executam comandos privilegiados nem alteram arquiteturas'

curl() { printf 'curl %s\n' "$*" >> "$CALLS"; }
reset_packages
JUNO_HOME="$TEST_ROOT/readonly-home"
juno_preflight_install readonly
[[ $(wc -l < "$CALLS") == 1 && ! -e $JUNO_STATE/packages && ! -e $JUNO_HOME ]]
grep -q 'https://zorin.com/' "$CALLS"
ok 'preflight somente leitura consulta identificação e HTTPS sem criar arquivos'

_txn_require_lock() { return 0; }
_juno_display_manager_alias() { printf '/usr/lib/systemd/system/gdm3.service\n'; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$CALLS"
    [[ $1 == get-default && $# == 1 ]] || return 99
    printf 'graphical.target\n'
}
reset_packages
juno_configure_gdm > "$TEST_ROOT/output"
[[ $(wc -l < "$CALLS") == 1 ]]
grep -q 'GDM já está configurado' "$TEST_ROOT/output"
ok 'GDM3 nativo é reconhecido e preservado sem habilitar ou reiniciar serviços'

_juno_display_manager_alias() { return 0; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$CALLS"
    case $1 in
        get-default) printf 'graphical.target\n' ;;
        is-enabled) printf 'disabled\n'; return 1 ;;
        is-active) printf 'inactive\n'; return 3 ;;
        enable) [[ $# == 2 && $2 == gdm3.service ]] ;;
        *) return 99 ;;
    esac
}
sync() { return 0; }
reset_packages
juno_configure_gdm > "$TEST_ROOT/output"
grep -Fx 'systemctl enable gdm3.service' "$CALLS" >/dev/null
if grep -q 'systemctl \(start\|restart\|disable\)' "$CALLS"; then exit 1; fi
[[ ! -e $JUNO_STATE/gdm-enable.pending.tsv ]]
ok 'sem gerenciador configurado habilita somente a unidade GDM3 sem iniciar serviços'

printf '%s cenários de plataforma passaram (APT e serviços simulados).\n' "$passed"
