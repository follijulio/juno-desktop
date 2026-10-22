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
DPKG_CALLS="$TEST_ROOT/dpkg-calls"
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
JUNO_WITH_DEV_TOOLS=1
juno_set_packages
[[ ${JUNO_PACKAGES[*]} == "${JUNO_ARCH_PACKAGES[*]}" ]]
JUNO_WITH_DEV_TOOLS=0
ok 'Arch preserva os pacotes e o serviço GDM existentes'

fixture 'ID="zorin"' "VERSION_ID='18.1'" 'VERSION_CODENAME=noble' 'UBUNTU_CODENAME="noble"'
juno_detect_platform "$TEST_ROOT/os-release"
[[ $JUNO_PLATFORM == zorin && $JUNO_ZORIN_VERSION == 18.1 && $JUNO_UBUNTU_VERSION == 24.04 ]]
[[ $(juno_gdm_service) == gdm3.service && $(juno_platform_network_url) == https://zorin.com/ ]]
juno_set_packages
[[ " ${JUNO_PACKAGES[*]} " == *' fonts-jetbrains-mono '* && " ${JUNO_PACKAGES[*]} " == *' python3-gi '* ]]
for package in gdm gdm3 gnome-shell gnome-session pipewire pipewire-pulse pulseaudio \
    steam discord firefox ttf-jetbrains-mono-nerd uv qt6-wayland "${JUNO_ZORIN_DEV_PACKAGES[@]}"; do
    [[ " ${JUNO_PACKAGES[*]} " != *" $package "* ]]
done
ok 'Zorin 18.1 usa nomes APT sem substituir sessão, login, navegador ou áudio'

for package in git python3 nodejs xdg-utils; do
    [[ " ${JUNO_PACKAGES[*]} " == *" $package "* ]]
done
JUNO_WITH_DEV_TOOLS=1
juno_set_packages
[[ ${#JUNO_PACKAGES[@]} == $((${#JUNO_ZORIN_PACKAGES[@]} + ${#JUNO_ZORIN_DEV_PACKAGES[@]})) ]]
for package in "${JUNO_ZORIN_DEV_PACKAGES[@]}"; do
    [[ " ${JUNO_PACKAGES[*]} " == *" $package "* ]]
done
JUNO_WITH_DEV_TOOLS=invalid
expect_failure juno_set_packages
JUNO_WITH_DEV_TOOLS=0
juno_set_packages
[[ ${JUNO_PACKAGES[*]} == "${JUNO_ZORIN_PACKAGES[*]}" ]]
ok 'Zorin mantém integração essencial e só seleciona compiladores e ferramentas com opção explícita'

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
    printf '%s\n' "$*" >> "$DPKG_CALLS"
    [[ $# == 2 && $1 == -W ]] || return 99
    case $2 in
        '-f=${binary:Package}\t${Architecture}\t${Status}\n')
            [[ $DPKG_INVENTORY_FAIL == no ]] || return 2
            local package missing_packages
            missing_packages=$(< "$MISSING")
            for package in "${JUNO_PACKAGES[@]}" gnome-shell gnome-session-bin gsettings-desktop-schemas gdm3; do
                [[ $'\n'$missing_packages$'\n' == *$'\n'"$package"$'\n'* ]] && continue
                printf '%s\tamd64\tinstall ok installed\n' "$package"
            done
            ;;
        '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n')
            printf 'kitty\t0\tinstalled\n'
            ;;
        *) return 99 ;;
    esac
}
apt-get() {
    printf 'apt-get %s\n' "$*" >> "$CALLS"
    case $1 in
        update) [[ $APT_UPDATE_FAIL == no ]] ;;
        install)
            [[ $2 == --no-install-recommends && $3 == --no-upgrade && $4 == --no-remove && $5 == -- ]] || return 99
            [[ $APT_INSTALL_FAIL == no ]] || return 28
            [[ $APT_LEAVE_MISSING == yes ]] || : > "$MISSING"
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
    : > "$DPKG_CALLS"
    : > "$MISSING"
    APT_UPDATE_FAIL=no; APT_INSTALL_FAIL=no; APT_CANDIDATE=yes
    DPKG_INVENTORY_FAIL=no; APT_LEAVE_MISSING=no
}

reset_packages
juno_install_packages > "$TEST_ROOT/output"
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages ]]
[[ $(wc -l < "$DPKG_CALLS") == 1 ]]
ok 'dependências presentes usam uma consulta DPKG sem sudo, índices ou reinstalação'

(
    declare -A inventory=([stale]=1)
    dpkg-query() {
        printf '%s\n' $'kitty:i386\ti386\tinstall ok installed' \
            $'kitty:amd64\tamd64\tdeinstall ok config-files' \
            $'fonts-roboto\tall\tinstall ok installed' \
            $'libsecret-1-0:i386\ti386\tinstall ok installed' \
            $'libsecret-1-0:amd64\tamd64\tinstall ok installed' \
            $'curl\tamd64\tinstall ok unpacked' \
            $'jq\tamd64\thold ok installed' \
            $'mpv\tamd64\tinstall reinstreq installed'
    }
    _juno_dpkg_inventory inventory
    [[ -z ${inventory[kitty]:-} && -z ${inventory[stale]:-} && -z ${inventory[curl]:-} && -z ${inventory[mpv]:-} ]]
    [[ ${inventory[fonts-roboto]:-} == 1 && ${inventory[libsecret-1-0]:-} == 1 && ${inventory[jq]:-} == 1 ]]
)
ok 'inventário em lote aceita retidos instalados e descarta cache antigo, estados incompletos e i386'

reset_packages
DPKG_INVENTORY_FAIL=yes
expect_failure juno_install_packages
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages && $(wc -l < "$DPKG_CALLS") == 1 ]]
grep -q 'inventário de pacotes DPKG' "$TEST_ROOT/error.log"
ok 'falha de inventário interrompe antes de sudo sem confundir todos os pacotes com ausentes'

reset_packages
printf 'kitty\nfonts-jetbrains-mono\n' > "$MISSING"
juno_install_packages > "$TEST_ROOT/output"
grep -Fx 'apt-get update' "$CALLS" >/dev/null
grep -Fx 'apt-get install --no-install-recommends --no-upgrade --no-remove -- kitty fonts-jetbrains-mono' "$CALLS" >/dev/null
[[ $(wc -l < "$DPKG_CALLS") == 4 ]]
[[ $(find "$JUNO_STATE/packages" -name '*.before.txt' | wc -l) == 1 ]]
[[ $(find "$JUNO_STATE/packages" -name '*.after.txt' | wc -l) == 1 ]]
ok 'APT recebe só ausentes sem recomendados, upgrades ou remoções; usa inventário em lote antes e depois'

reset_packages
printf 'kitty\n' > "$MISSING"
APT_LEAVE_MISSING=yes
expect_failure juno_install_packages
[[ $(wc -l < "$DPKG_CALLS") == 4 && $(find "$JUNO_STATE/packages" -name '*.after.txt' | wc -l) == 1 ]]
grep -q 'ausente após a instalação: kitty' "$TEST_ROOT/error.log"
ok 'validação posterior relê DPKG e rejeita dependência ainda ausente após sucesso APT'

reset_packages
juno_install_packages > "$TEST_ROOT/output"
printf 'kitty\n' > "$MISSING"
juno_install_packages >> "$TEST_ROOT/output"
[[ $(wc -l < "$DPKG_CALLS") == 5 ]]
grep -Fx 'apt-get install --no-install-recommends --no-upgrade --no-remove -- kitty' "$CALLS" >/dev/null
ok 'nova operação consulta inventário atual sem reutilizar o cache da execução anterior'

reset_packages
printf 'xdg-desktop-portal-gnome\n' > "$MISSING"
juno_install_packages > "$TEST_ROOT/output"
grep -Fx 'apt-get install --no-install-recommends --no-upgrade --no-remove -- xdg-desktop-portal-gnome' "$CALLS" >/dev/null
ok 'portal GNOME ausente é complementado sem rejeitar uma sessão GNOME existente'

reset_packages
printf 'gnome-shell\n' > "$MISSING"
expect_failure juno_install_packages
[[ ! -s $CALLS && ! -e $JUNO_STATE/packages ]]
[[ $(wc -l < "$DPKG_CALLS") == 1 ]]
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
[[ ! -s $DPKG_CALLS ]]
grep -q 'apt-get install --no-install-recommends --no-upgrade --no-remove --' "$TEST_ROOT/plan"
if grep -q 'golang-go\|cargo\|build-essential' "$TEST_ROOT/plan"; then exit 1; fi
JUNO_WITH_DEV_TOOLS=1
juno_packages_plan > "$TEST_ROOT/plan-dev"
grep -q 'golang-go' "$TEST_ROOT/plan-dev"
grep -q 'cargo' "$TEST_ROOT/plan-dev"
[[ ! -s $CALLS && ! -s $DPKG_CALLS && ! -e $JUNO_STATE/packages ]]
JUNO_WITH_DEV_TOOLS=0
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
