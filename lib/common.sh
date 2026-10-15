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

juno_define_targets() {
    # Contrato compartilhado com transaction.sh e validate.sh.
    # shellcheck disable=SC2034
    JUNO_TARGETS=(
        .config/hypr .config/waybar .config/rofi .config/mako .config/kitty
        .config/juno .config/xdg-desktop-portal .local/share/fonts/juno
        .local/share/juno-desktop
    )
    # shellcheck disable=SC2034
    JUNO_SOURCES=(
        "$JUNO_ROOT/config/hypr" "$JUNO_ROOT/config/waybar"
        "$JUNO_ROOT/config/rofi" "$JUNO_ROOT/config/mako"
        "$JUNO_ROOT/config/kitty" "$JUNO_ROOT/config/juno"
        "$JUNO_ROOT/config/xdg-desktop-portal" "$JUNO_ROOT/assets/fonts/spacemono"
        "$JUNO_ROOT/assets/desktop"
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
    case $name in logs|packages) ;; *) juno_die 'Subdiretório de estado inválido.' ;; esac
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
            fc-cache -f >/dev/null 2>&1 || juno_warn 'Atualize o cache das fontes após a recuperação com fc-cache -fv.'
        fi
    fi
    juno_warn 'Pacotes e atualizações do sistema não são revertidos. Consulte o registro da execução.'
    exit "$status"
}
