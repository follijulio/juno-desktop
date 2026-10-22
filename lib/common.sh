#!/usr/bin/env bash
# Funções do instalador; este arquivo não executa alterações ao ser carregado.

juno_log() { printf '[Juno] %s\n' "$*"; }
juno_warn() { printf '[Juno · atenção] %s\n' "$*" >&2; }
juno_die() { printf '[Juno · erro] %s\n' "$*" >&2; exit 1; }

juno_require() {
    local command_name
    for command_name in "$@"; do
        command -v "$command_name" >/dev/null 2>&1 ||
            juno_die "Utilitário necessário não encontrado: $command_name."
    done
}

juno_browser_desktop() {
    # Zorin's small APT Firefox wizard has no real browser in /usr/lib.
    # Preserve an existing native Firefox instead of creating a duplicate.
    if [[ ${JUNO_PLATFORM:-arch} != zorin || (
        -f /usr/share/applications/firefox.desktop && (
            -x /usr/lib/firefox/firefox || -x /usr/lib/firefox/firefox-bin
        )
    ) ]]; then
        printf 'firefox.desktop\n'
    else
        printf 'org.mozilla.firefox.desktop\n'
    fi
}

juno_define_targets() {
    # Contrato compartilhado com transaction.sh e validate.sh.
    # shellcheck disable=SC2034
    JUNO_TARGETS=(
        .config/kitty .config/juno-gnome .local/share/fonts/juno
        .local/share/juno-desktop .bashrc .config/Code/User/settings.json
        .config/environment.d/90-juno.conf
        .local/share/icons/Juno
        .config/mimeapps.list
        .local/share/icons/Juno-Auto .local/share/applications
        .config/autostart/juno-icons.desktop
    )
    # shellcheck disable=SC2034
    JUNO_SOURCES=(
        "$JUNO_ROOT/config/kitty" "$JUNO_ROOT/config/juno-gnome"
        "$JUNO_ROOT/assets/fonts/spacemono" "$JUNO_ROOT/assets/desktop"
        "$JUNO_ROOT/config/juno-gnome/templates/bashrc"
        "$JUNO_ROOT/config/juno-gnome/templates/settings.json"
        "$JUNO_ROOT/config/environment.d/90-juno.conf"
        "$JUNO_ROOT/assets/icons/Juno"
        "$JUNO_ROOT/config/juno-gnome/templates/mimeapps.list"
        "$JUNO_ROOT/config/juno-gnome/templates/empty"
        "$JUNO_ROOT/config/juno-gnome/templates/empty"
        "$JUNO_ROOT/config/juno-gnome/templates/icons-autostart.desktop"
    )
}

juno_on_exit() {
    local status=$1
    if (( status != 0 )); then
        juno_on_failure "$status" 'saída antecipada'
    fi
}


juno_begin_log() {
    local log_dir="$JUNO_STATE/logs"
    juno_private_subdir logs
    JUNO_LOG="$log_dir/install-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
    : > "$JUNO_LOG"
    chmod 600 -- "$JUNO_LOG"
    exec > >(tee -a "$JUNO_LOG") 2>&1
    juno_log "Registro desta execução: $JUNO_LOG"
}

juno_private_subdir() {
    local name=$1 path
    case $name in logs|packages|apps|browser) ;; *) juno_die 'Subdiretório de estado inválido.' ;; esac
    path="$JUNO_STATE/$name"
    [[ ! -L $path ]] || juno_die "O diretório de estado não pode ser um link: $path."
    if [[ -e $path ]]; then
        [[ -d $path && $(stat -c %u -- "$path") == "$(id -u)" ]] ||
            juno_die "Diretório de estado inválido ou de outro usuário: $path."
    fi
    mkdir -p -- "$path"
    chmod 700 -- "$path"
}

juno_on_failure() {
    local status=$1 reason=$2 recovery_status=0
    trap - ERR INT TERM EXIT
    set +e
    juno_warn "Operação interrompida ($reason). Código: $status."
    txn_abort
    recovery_status=$?
    if (( recovery_status != 0 )); then
        juno_warn "Recuperação pendente. Preserve $JUNO_STATE e siga as instruções exibidas."
    else
        txn_cleanup_stage
        if command -v fc-cache >/dev/null 2>&1; then
            juno_refresh_font_cache >/dev/null 2>&1 || juno_warn 'Não foi possível atualizar o cache das fontes após a recuperação; confira o registro.'
        fi
    fi
    juno_warn 'Pacotes e atualizações do sistema não são revertidos. Consulte o registro da execução.'
    exit "$status"
}
