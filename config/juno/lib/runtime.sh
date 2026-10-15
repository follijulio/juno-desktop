#!/usr/bin/env bash
# Shared desktop helpers. This file does not start or modify the session.

# Shared path contract consumed by the scripts that source this file.
# shellcheck disable=SC2034
JUNO_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME:?HOME não definido}/.config}
# shellcheck disable=SC2034
JUNO_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
# shellcheck disable=SC2034
JUNO_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}

juno_notice() {
    local urgency=$1 title=$2 message=$3
    printf '[Juno] %s: %s\n' "$title" "$message" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name=Juno --urgency="$urgency" -- "$title" "$message" >/dev/null 2>&1 || true
    fi
}

juno_require() {
    local command_name
    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            juno_notice critical 'Recurso indisponível' "O comando $command_name não está instalado."
            return 1
        fi
    done
}

juno_require_session() {
    if [[ -z ${WAYLAND_DISPLAY:-} || -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        juno_notice critical 'Sessão indisponível' 'Execute este recurso dentro da sessão Juno no Hyprland.'
        return 1
    fi
}

juno_prepare_runtime() {
    if [[ -z ${XDG_RUNTIME_DIR:-} || ! -d $XDG_RUNTIME_DIR || ! -O $XDG_RUNTIME_DIR || ! -w $XDG_RUNTIME_DIR ]]; then
        juno_notice critical 'Sessão indisponível' 'O diretório temporário privado da sessão não está disponível.'
        return 1
    fi
    JUNO_RUNTIME_DIR=$XDG_RUNTIME_DIR/juno-desktop
    if [[ -L $JUNO_RUNTIME_DIR || ( -e $JUNO_RUNTIME_DIR && ( ! -d $JUNO_RUNTIME_DIR || ! -O $JUNO_RUNTIME_DIR ) ) ]]; then
        juno_notice critical 'Diretório inválido' 'O diretório temporário Juno não pode ser um link simbólico.'
        return 1
    fi
    mkdir -p -- "$JUNO_RUNTIME_DIR"
    chmod 700 -- "$JUNO_RUNTIME_DIR"
}

juno_safe_output() {
    local path=$1
    if [[ -L $path || ( -e $path && ( ! -f $path || ! -O $path ) ) ]]; then
        juno_notice critical 'Arquivo inválido' 'Um arquivo de trabalho Juno é um link, não é um arquivo regular ou pertence a outro usuário.'
        return 1
    fi
}

juno_prepare_log_dir() {
    local canonical_home canonical_state canonical_logs
    JUNO_LOG_DIR=$JUNO_STATE_HOME/juno-desktop
    canonical_home=$(realpath -e -- "$HOME")
    canonical_state=$(realpath -m -- "$JUNO_STATE_HOME")
    canonical_logs=$(realpath -m -- "$JUNO_LOG_DIR")
    if [[ $canonical_state != "$canonical_home/"* || $canonical_logs != "$canonical_state/juno-desktop" ||
          -L $JUNO_LOG_DIR || ( -e $JUNO_LOG_DIR && ( ! -d $JUNO_LOG_DIR || ! -O $JUNO_LOG_DIR ) ) ]]; then
        juno_notice critical 'Diretório inválido' 'Os logs Juno precisam de um diretório próprio, dentro da pasta pessoal e sem link simbólico.'
        return 1
    fi
    mkdir -p -- "$JUNO_LOG_DIR"
    chmod 700 -- "$JUNO_LOG_DIR"
}

juno_session_key() {
    printf '%s' "${HYPRLAND_INSTANCE_SIGNATURE//[^a-zA-Z0-9_.-]/_}"
}

# Compare the process environment so a second graphical session stays isolated.
juno_is_running() {
    local name=$1 pid entry process_display process_runtime process_signature
    while IFS= read -r pid; do
        [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/environ ]] || continue
        process_display='' process_runtime='' process_signature=''
        # The process can exit between pgrep, the readable check and the open.
        if ! {
            while IFS= read -r -d '' entry; do
                case "$entry" in
                    WAYLAND_DISPLAY=*) process_display=${entry#*=} ;;
                    XDG_RUNTIME_DIR=*) process_runtime=${entry#*=} ;;
                    HYPRLAND_INSTANCE_SIGNATURE=*) process_signature=${entry#*=} ;;
                esac
            done
        } 2>/dev/null < "/proc/$pid/environ"; then
            continue
        fi
        if [[ $process_display == "$WAYLAND_DISPLAY" && $process_runtime == "$XDG_RUNTIME_DIR" &&
              ( -z $process_signature || $process_signature == "$HYPRLAND_INSTANCE_SIGNATURE" ) ]]; then
            return 0
        fi
    done < <(pgrep -u "$UID" -x "$name" 2>/dev/null || true)
    return 1
}
