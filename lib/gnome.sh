#!/usr/bin/env bash
# GNOME integration: per-key settings and conservative display-manager setup.

_juno_gsettings_helper() {
    printf '%s/config/juno-gnome/lib/gnome_settings.py\n' "$JUNO_ROOT"
}

_juno_gsettings_run() (
    local operation=$1 helper runtime user_bus temporary_runtime='' status
    shift
    helper=$(_juno_gsettings_helper)
    juno_require python3
    [[ -f $helper && ! -L $helper ]] || { juno_warn 'Helper GNOME ausente ou inválido.'; return 2; }
    local -a context=(env -u GSETTINGS_SCHEMA_DIR "GSETTINGS_BACKEND=dconf" "HOME=$JUNO_HOME")
    # Only static planning avoids dconf entirely. Even reads can create dconf
    # shared-memory files, so backend operations need a safe runtime directory.
    case $operation in
        desired)
            if "${context[@]}" python3 "$helper" "$operation" --home "$JUNO_HOME" "$@"; then return 0; else return $?; fi
            ;;
    esac
    (( EUID != 0 )) || { juno_warn 'GSettings deve ser aplicado como usuário comum.'; return 2; }
    runtime="/run/user/$(id -u)"
    if [[ -d $runtime && ! -L $runtime && $(stat -c %u -- "$runtime") == "$(id -u)" && $(stat -c %a -- "$runtime") == 700 ]]; then
        user_bus="$runtime/bus"
        if [[ -S $user_bus && $(stat -c %u -- "$user_bus") == "$(id -u)" ]]; then
            if "${context[@]}" "XDG_RUNTIME_DIR=$runtime" "DBUS_SESSION_BUS_ADDRESS=unix:path=$user_bus" \
                python3 "$helper" "$operation" --home "$JUNO_HOME" "$@"; then return 0; else return $?; fi
        fi
    else
        # Text/SSH sessions without pam_systemd get a private temporary runtime.
        [[ -d $JUNO_STATE && ! -L $JUNO_STATE ]] || { juno_warn 'Estado privado necessário para iniciar D-Bus temporário.'; return 2; }
        temporary_runtime=$(mktemp -d "$JUNO_STATE/.gnome-runtime.XXXXXXXX") || return 2
        runtime=$temporary_runtime
        chmod 700 -- "$runtime" || return 2
        trap '[[ -z "$temporary_runtime" ]] || rm -rf -- "$temporary_runtime"' EXIT
    fi
    juno_require dbus-run-session
    if "${context[@]}" "XDG_RUNTIME_DIR=$runtime" dbus-run-session -- \
        python3 "$helper" "$operation" --home "$JUNO_HOME" "$@"; then status=0; else status=$?; fi
    return "$status"
)

juno_gsettings_desired() { _juno_gsettings_run desired --output "$1"; }
juno_gsettings_snapshot() { _juno_gsettings_run snapshot --output "$1"; }
# The transaction module also passes a snapshot to this optional argument.
# shellcheck disable=SC2120
juno_gsettings_validate() {
    if [[ $# == 0 ]]; then _juno_gsettings_run validate; else _juno_gsettings_run validate --input "$1"; fi
}
juno_gsettings_apply() {
    _juno_gsettings_run apply || return $?
    juno_gsettings_verify
}
juno_gsettings_restore() {
    _juno_gsettings_run restore --input "$1" || return $?
    juno_gsettings_verify "$1"
}
juno_gsettings_verify() {
    if [[ $# == 0 ]]; then _juno_gsettings_run verify; else _juno_gsettings_run verify --input "$1"; fi
}
juno_gsettings_recovery_check() { _juno_gsettings_run recovery-check --before "$1" --desired "$2"; }

juno_gnome_plan() {
    juno_log 'GNOME: Shell, Configurações, Nautilus, chaveiro e portal nativo; nenhuma remoção de pacotes existentes.'
    juno_log 'Perfil: Roboto na interface, Space Mono em apps monoespaçados e wallpaper Ghibli; JetBrains Mono regular/Nerd para Kitty e VS Code.'
    juno_log 'GDM: habilitar para o próximo boot somente se nenhum outro gerenciador de login estiver configurado; sem iniciar ou reiniciar serviços.'
    juno_log 'GSettings: validação de schemas e permissões após instalar python-gobject; backup por chave, incluindo valores ausentes.'
}

juno_validate_gnome() {
    juno_require gnome-shell gsettings python3 dbus-run-session
    gnome-shell --version || return 1
    # Validate the desired profile, not a snapshot.
    # shellcheck disable=SC2119
    juno_gsettings_validate || return $?
}

_juno_display_manager_alias() {
    local path=/etc/systemd/system/display-manager.service
    if [[ -e $path || -L $path ]]; then realpath -m -- "$path"; fi
    return 0
}

_juno_existing_display_manager() {
    local alias service state active
    alias=$(_juno_display_manager_alias) || return 2
    if [[ -n $alias ]]; then printf '%s\n' "$alias"; return 0; fi
    # Some managers are enabled without installing the usual shared alias.
    for service in gdm sddm lightdm greetd ly lxdm xdm slim emptty lemurs; do
        state=$(systemctl is-enabled "$service.service" 2>/dev/null) || :
        case $state in
            enabled|enabled-runtime|linked|linked-runtime|alias)
                printf '%s.service\n' "$service"; return 0 ;;
            disabled|static|indirect|generated|transient|not-found|masked|masked-runtime) ;;
            *) return 2 ;;
        esac
        active=$(systemctl is-active "$service.service" 2>/dev/null) || :
        case $active in
            active|activating|reloading|refreshing|deactivating)
                printf '%s.service\n' "$service"; return 0 ;;
            inactive|failed|unknown|not-found) ;;
            *) return 2 ;;
        esac
    done
    return 1
}

_juno_gdm_archive_pending() {
    local result=$1 pending="$JUNO_STATE/gdm-enable.pending.tsv" archive
    [[ -f $pending && ! -L $pending ]] || return 1
    juno_private_subdir logs
    printf 'result\t%s\n' "$result" >> "$pending" || return 1
    archive="$JUNO_STATE/logs/gdm-$(date -u +%Y%m%dT%H%M%SZ)-$$.tsv"
    [[ ! -e $archive && ! -L $archive ]] || return 1
    mv -T -- "$pending" "$archive" || return 1
    sync -f "$JUNO_STATE" || return 1
    juno_log "Registro do login gráfico: $archive"
}

juno_configure_gdm() {
    local existing='' default_target state pending="$JUNO_STATE/gdm-enable.pending.tsv" query_status
    _txn_require_lock || return 1
    juno_require systemctl sudo
    if [[ -e $pending || -L $pending ]]; then
        [[ -f $pending && ! -L $pending && $(stat -c %u -- "$pending") == "$(id -u)" ]] || {
            juno_warn 'Registro GDM pendente inválido; preserve-o para revisão.'; return 1;
        }
        juno_warn 'Uma habilitação anterior do GDM foi interrompida; conferindo o estado atual sem desativar serviços.'
        _juno_gdm_archive_pending inspected-after-interruption || return 1
    fi
    default_target=$(systemctl get-default) || { juno_warn 'Não foi possível consultar o alvo de boot; GDM não foi alterado.'; return 1; }
    if [[ $default_target != graphical.target ]]; then
        juno_warn "Alvo de boot preservado: $default_target. Para abrir o login gráfico no boot, execute explicitamente: sudo systemctl set-default graphical.target"
    fi
    if existing=$(_juno_existing_display_manager); then
        if [[ ${existing##*/} == gdm.service ]]; then
            juno_log 'GDM já está configurado. Nenhum serviço foi iniciado ou reiniciado.'
        else
            juno_warn "Gerenciador de login preservado: $existing. Escolha GNOME na seleção de sessões desse gerenciador."
            juno_warn 'Para trocar para GDM, revise manualmente o serviço atual antes de habilitar gdm.service; Juno não substitui seu gerenciador de login.'
        fi
        return 0
    else
        query_status=$?
        (( query_status == 1 )) || { juno_warn 'Não foi possível identificar o gerenciador de login; GDM não foi alterado.'; return 1; }
    fi
    state=$(systemctl is-enabled gdm.service 2>/dev/null) || :
    case $state in
        masked|masked-runtime)
            juno_warn 'GDM está mascarado. A máscara foi preservada; revise-a manualmente se desejar usar GDM.'
            return 0 ;;
        disabled|static|indirect|generated|transient) ;;
        *) juno_warn 'Estado GDM inesperado; nenhuma habilitação foi tentada.'; return 1 ;;
    esac
    # Since no existing manager is disabled, interruption can never remove it.
    # Persist the intention so a later run can diagnose a partial enable.
    (umask 077; printf 'juno-gdm\t1\nprevious\t%s\ndefault-target\t%s\naction\tenable-gdm-only\n' "$state" "$default_target" > "$pending") || return 1
    sync -f "$JUNO_STATE" || return 1
    if sudo systemctl enable gdm.service; then
        _juno_gdm_archive_pending enabled || return 1
        juno_log 'GDM habilitado para o próximo boot gráfico. Para desfazer somente esta habilitação: sudo systemctl disable gdm.service'
    else
        _juno_gdm_archive_pending enable-failed || :
        juno_warn 'Não foi possível habilitar GDM. As configurações GNOME já confirmadas foram preservadas; confira systemctl is-enabled gdm.service.'
        return 1
    fi
}
