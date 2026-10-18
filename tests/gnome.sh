#!/usr/bin/env bash
# Service/logind calls are simulated; no host service is modified.
# shellcheck disable=SC2329,SC2032
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/gnome.sh
source "$ROOT/lib/gnome.sh"
# shellcheck source=../lib/preflight.sh
source "$ROOT/lib/preflight.sh"
# shellcheck source=../lib/packages.sh
source "$ROOT/lib/packages.sh"

TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
CALLS="$TEST_ROOT/calls"
passed=0
ok() { passed=$((passed + 1)); printf 'OK: %s\n' "$1"; }
expect_status() {
    local expected=$1 status=0
    shift
    "$@" > "$TEST_ROOT/output" 2>&1 || status=$?
    if (( status != expected )); then
        cat "$TEST_ROOT/output" >&2
        printf 'Status esperado %s; recebido %s.\n' "$expected" "$status" >&2
        exit 1
    fi
}
_txn_require_lock() { return 0; }
sync() { return 0; }
_juno_display_manager_alias() { [[ -z $STUB_ALIAS ]] || printf '%s\n' "$STUB_ALIAS"; return 0; }
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$CALLS"
    case $1 in
        get-default) printf '%s\n' "$STUB_TARGET" ;;
        is-enabled)
            [[ $STUB_QUERY_ERROR != yes ]] || return 1
            if [[ $2 == "$STUB_ENABLED_DM" ]]; then printf 'enabled\n'; return 0; fi
            if [[ $2 == gdm.service ]]; then printf '%s\n' "$STUB_GDM"; else printf 'not-found\n'; fi
            return 1 ;;
        is-active)
            if [[ $2 == "$STUB_ACTIVE_DM" ]]; then printf 'active\n'; return 0; fi
            printf 'inactive\n'; return 3 ;;
        enable)
            [[ $2 == gdm.service && $# == 2 ]] || return 99
            [[ $STUB_ENABLE_FAIL != yes ]] || return 1
            STUB_ENABLED_DM=gdm.service ;;
        *) printf 'Ação systemctl não autorizada: %s\n' "$*" >&2; return 99 ;;
    esac
}
sudo() { "$@"; }
reset_manager() {
    JUNO_STATE="$TEST_ROOT/state-$passed"
    mkdir -p "$JUNO_STATE"
    : > "$CALLS"
    STUB_ALIAS=''; STUB_ENABLED_DM=''; STUB_ACTIVE_DM=''
    STUB_QUERY_ERROR=no; STUB_ENABLE_FAIL=no; STUB_GDM=disabled; STUB_TARGET=graphical.target
}
assert_no_enable() { if grep -q 'systemctl enable' "$CALLS"; then cat "$CALLS" >&2; exit 1; fi; }

reset_manager
STUB_ALIAS=/usr/lib/systemd/system/sddm.service
expect_status 0 juno_configure_gdm
assert_no_enable
grep -q 'sddm.service' "$TEST_ROOT/output"
ok 'alias de outro gerenciador preservado'

reset_manager
STUB_ENABLED_DM=lightdm.service
expect_status 0 juno_configure_gdm
assert_no_enable
ok 'gerenciador habilitado sem alias preservado'

reset_manager
STUB_ACTIVE_DM=greetd.service
expect_status 0 juno_configure_gdm
assert_no_enable
ok 'gerenciador ativo preservado mesmo sem habilitação'

reset_manager
STUB_ENABLED_DM=gdm.service
expect_status 0 juno_configure_gdm
assert_no_enable
ok 'GDM existente não é habilitado outra vez'

reset_manager
STUB_TARGET=multi-user.target
expect_status 0 juno_configure_gdm
grep -Fx 'systemctl enable gdm.service' "$CALLS" >/dev/null
[[ $(grep -c '^systemctl enable ' "$CALLS") == 1 ]]
[[ ! -e $JUNO_STATE/gdm-enable.pending.tsv ]]
grep -q 'multi-user.target' "$TEST_ROOT/output"
grep -q $'result\tenabled' "$JUNO_STATE"/logs/*.tsv
ok 'sem gerenciador habilita apenas GDM e preserva alvo de boot'

reset_manager
STUB_GDM=masked
expect_status 0 juno_configure_gdm
assert_no_enable
ok 'máscara GDM preservada'

reset_manager
STUB_QUERY_ERROR=yes
expect_status 1 juno_configure_gdm
assert_no_enable
[[ ! -e $JUNO_STATE/gdm-enable.pending.tsv ]]
ok 'falha ao consultar systemd interrompe sem habilitar GDM'

reset_manager
STUB_ENABLE_FAIL=yes
expect_status 1 juno_configure_gdm
grep -q $'result\tenable-failed' "$JUNO_STATE"/logs/*.tsv
ok 'falha de habilitação mantém registro e não inicia serviço'

reset_manager
printf 'juno-gdm\t1\nprevious\tdisabled\naction\tenable-gdm-only\n' > "$JUNO_STATE/gdm-enable.pending.tsv"
STUB_ENABLED_DM=gdm.service
expect_status 0 juno_configure_gdm
assert_no_enable
[[ ! -e $JUNO_STATE/gdm-enable.pending.tsv ]]
grep -q $'result\tinspected-after-interruption' "$JUNO_STATE"/logs/*.tsv
ok 'habilitação interrompida é inspecionada sem reiniciar serviços'

unset WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE
STUB_SESSIONS="test $EUID user seat0 tty2"
STUB_SESSION_TYPE=wayland; STUB_SESSION_STATE=online; STUB_LOGINCTL_ERROR=no
loginctl() {
    [[ $STUB_LOGINCTL_ERROR != yes ]] || return 1
    case $1 in
        list-sessions) printf '%s\n' "$STUB_SESSIONS" ;;
        show-session) printf 'Type=%s\nState=%s\n' "$STUB_SESSION_TYPE" "$STUB_SESSION_STATE" ;;
        *) return 99 ;;
    esac
}
expect_status 0 juno_has_graphical_session
STUB_SESSION_TYPE=x11
expect_status 0 juno_has_graphical_session
ok 'logind identifica sessão gráfica em outro TTY mesmo inativa'

STUB_LOGINCTL_ERROR=yes
expect_status 2 juno_has_graphical_session
ok 'erro logind é diferente de ausência de sessão'

if [[ $(uname -s) != Linux ]]; then
    STUB_LOGINCTL_ERROR=no
    STUB_SESSION_TYPE='tty'
    expect_status 1 juno_has_graphical_session
    STUB_SESSION_TYPE=wayland; STUB_SESSION_STATE=closing
    expect_status 1 juno_has_graphical_session
    STUB_SESSION_STATE=active; STUB_SESSIONS="other $((EUID + 1)) other seat0 tty2"
    expect_status 1 juno_has_graphical_session
    ok 'sessão TTY, sessão encerrando e outro usuário não bloqueiam (sem /proc Linux)'
else
    printf 'AVISO: casos de ausência de sessão ignorados neste teste portátil por dependerem dos processos reais em /proc.\n'
fi

[[ " ${JUNO_PACKAGES[*]} " == *' gnome-shell '* && " ${JUNO_PACKAGES[*]} " == *' gdm '* ]]
[[ " ${JUNO_PACKAGES[*]} " == *' ttf-jetbrains-mono '* && " ${JUNO_PACKAGES[*]} " == *' ttf-jetbrains-mono-nerd '* ]]
for package in hyprland waybar rofi mako hyprlock hypridle xdg-desktop-portal-hyprland; do
    [[ " ${JUNO_PACKAGES[*]} " != *" $package "* ]]
done
ok 'pacotes GNOME e JetBrains substituem dependências específicas Hyprland'
printf '%s cenários GNOME passaram (systemd/logind simulados).\n' "$passed"
