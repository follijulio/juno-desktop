#!/usr/bin/env bash

juno_preflight_base() {
    [[ $(uname -s) == Linux && -f /etc/arch-release ]] ||
        juno_die 'Este instalador exige Arch Linux. Nenhuma configuração foi aplicada.'
    [[ $(uname -m) == x86_64 ]] || juno_die 'Arquitetura suportada: x86_64.'
    (( EUID != 0 )) || juno_die 'Execute como usuário comum. O instalador solicitará sudo para os pacotes.'
    # diffutils is installed by pacman; a fresh Arch does not have it yet.
    juno_require id getent realpath stat find tar gzip sha256sum flock date mktemp cp mv rm chmod df awk sort readlink tee cat sync
    local actual_user account_home resolved_home parent resolved_parent owner xdg_value expected mode os_id
    os_id=$(awk -F= '$1 == "ID" {gsub(/"/, "", $2); print $2; exit}' /etc/os-release)
    [[ $os_id == arch ]] || juno_die 'Somente Arch Linux oficial é suportado; distribuições derivadas não foram validadas.'
    actual_user=$(id -un)
    [[ ${USER:-} == "$actual_user" ]] || juno_die 'USER não corresponde ao usuário efetivo.'
    [[ -n ${HOME:-} && $HOME == /* && $HOME != / && $HOME != *$'\n'* && $HOME != *$'\t'* ]] ||
        juno_die 'HOME deve ser um caminho absoluto válido, sem caracteres de controle.'
    account_home=$(getent passwd "$(id -u)" | awk -F: '{print $6}')
    [[ -n $account_home ]] || juno_die 'Não foi possível consultar o diretório pessoal da conta.'
    resolved_home=$(realpath -e -- "$HOME")
    [[ $resolved_home == "$(realpath -e -- "$account_home")" ]] ||
        juno_die 'HOME não corresponde ao diretório pessoal registrado para a conta.'
    [[ $(stat -c %u -- "$resolved_home") == "$(id -u)" && -w $resolved_home ]] ||
        juno_die 'O diretório pessoal deve pertencer ao usuário e permitir gravação.'
    mode=$(stat -c %a -- "$resolved_home")
    (( (8#$mode & 0022) == 0 )) || juno_die 'O diretório pessoal não pode permitir gravação por grupo ou outros usuários.'
    JUNO_HOME=$resolved_home
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    export JUNO_HOME JUNO_STATE
    for parent in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
        case $parent in
            XDG_CONFIG_HOME) expected="$JUNO_HOME/.config" ;;
            XDG_DATA_HOME) expected="$JUNO_HOME/.local/share" ;;
            XDG_STATE_HOME) expected="$JUNO_HOME/.local/state" ;;
        esac
        xdg_value=${!parent:-$expected}
        [[ $xdg_value == /* && $(realpath -m -- "$xdg_value") == "$(realpath -m -- "$expected")" ]] ||
            juno_die "$parent personalizado não é suportado nesta versão. Destino esperado: $expected."
    done
    # realpath -m também resolve ancestrais existentes quando o destino não existe.
    for parent in .config .local .local/share .local/share/fonts .local/state .local/state/juno-desktop; do
        resolved_parent=$(realpath -m -- "$JUNO_HOME/$parent")
        [[ $resolved_parent == "$JUNO_HOME/"* ]] || juno_die "Caminho fora do diretório pessoal: $parent."
        if [[ -e $JUNO_HOME/$parent ]]; then
            [[ -d $JUNO_HOME/$parent && -w $JUNO_HOME/$parent ]] || juno_die "Diretório indisponível: $parent."
            owner=$(stat -Lc %u -- "$JUNO_HOME/$parent")
            [[ $owner == "$(id -u)" ]] || juno_die "Diretório de outro usuário: $parent."
            mode=$(stat -Lc %a -- "$JUNO_HOME/$parent")
            (( (8#$mode & 0022) == 0 )) || juno_die "Diretório permite gravação por grupo ou outros usuários: $parent."
        fi
    done
}

juno_has_graphical_session() {
    local sessions session uid session_type session_state proc command_name owner properties
    [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} || -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && return 0
    if command -v loginctl >/dev/null 2>&1; then
        sessions=$(loginctl list-sessions --no-legend --no-pager 2>/dev/null) || return 2
        while read -r session uid _; do
            [[ -n $session && $uid == "$EUID" ]] || continue
            properties=$(loginctl show-session "$session" --property=Type --property=State --no-pager 2>/dev/null) || return 2
            session_type=''; session_state=''
            while IFS='=' read -r command_name owner; do
                case $command_name in Type) session_type=$owner ;; State) session_state=$owner ;; esac
            done <<< "$properties"
            # An inactive graphical session on another VT is still logged in.
            if [[ $session_type == wayland || $session_type == x11 ]]; then
                [[ $session_state == closing ]] || return 0
            fi
        done <<< "$sessions"
    fi
    # Also detect manually started compositors not registered with logind.
    for proc in /proc/[0-9]*; do
        [[ -r $proc/comm && -r $proc/status ]] || continue
        command_name=$(cat "$proc/comm" 2>/dev/null) || continue
        case $command_name in Hyprland|gnome-shell|kwin_wayland|kwin_x11|sway|Xorg|Xwayland) ;; *) continue ;; esac
        owner=$(awk '/^Uid:/ {print $2; exit}' "$proc/status" 2>/dev/null) || continue
        [[ $owner == "$EUID" ]] && return 0
    done
    return 1
}

# Kept for old callers while the installer transitions to the generic check.
juno_has_hyprland_session() { juno_has_graphical_session; }

juno_preflight_transaction() {
    juno_require diff cmp
}

juno_preflight_terminal() {
    local status
    [[ -t 0 ]] || juno_die 'Execute a aplicação em um terminal de texto interativo (TTY).'
    if juno_has_graphical_session; then
        juno_die 'Saia de todas as sessões gráficas deste usuário, inclusive em outro TTY, antes de aplicar ou restaurar.'
    else
        status=$?
        (( status == 1 )) || juno_die 'Não foi possível consultar as sessões do logind. Verifique systemd-logind antes de continuar.'
    fi
}

juno_preflight_install() {
    local mode=$1 free_home free_root
    juno_require sudo pacman curl
    if [[ $mode == apply ]]; then
        juno_preflight_terminal
        [[ ! -e /var/lib/pacman/db.lck ]] || juno_die 'O pacman está ocupado. Aguarde a outra operação terminar.'
        free_home=$(df -Pk -- "$JUNO_HOME" | awk 'END {print $4}')
        free_root=$(df -Pk / | awk 'END {print $4}')
        (( free_home >= 524288 && free_root >= 2097152 )) ||
            juno_die 'Reserve ao menos 512 MiB no diretório pessoal e 2 GiB na raiz. O pacman verificará o espaço adicional.'
    fi
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 5 --max-time 20 --head https://archlinux.org/ >/dev/null ||
        juno_die 'Não foi possível acessar o Arch por HTTPS. Verifique rede, relógio e certificados.'
}
