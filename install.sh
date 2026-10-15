#!/usr/bin/env bash
set -euo pipefail
set -E

JUNO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly JUNO_ROOT
for module in common preflight packages validate transaction; do
    # shellcheck source=/dev/null
    source "$JUNO_ROOT/lib/$module.sh"
done

usage() {
    cat <<'HELP'
Juno Desktop — instalador para Arch Linux x86_64

Uso: bash install.sh [opção]
  --dry-run         Exibe verificações e alterações previstas, sem gravar arquivos.
  --list-backups    Lista os backups deste usuário.
  --rollback ID     Restaura um backup e preserva o estado atual em outro backup.
  --help            Exibe esta ajuda.

Sem opções: atualiza o Arch e instala a sessão Juno. Execute como usuário comum,
após sair da sessão gráfica e entrar em um terminal de texto (TTY).
HELP
}

juno_main() {
    local operation=install backup_id='' target comparison_status
    case ${1:-} in
        '') ;;
        --help|-h) usage; exit 0 ;;
        --dry-run) operation=dry-run ;;
        --list-backups) operation=list ;;
        --rollback)
            [[ $# -eq 2 ]] || { usage >&2; exit 2; }
            operation=rollback
            backup_id=$2
            ;;
        *) usage >&2; exit 2 ;;
    esac
    if [[ $operation != rollback && $# -gt 1 ]]; then
        usage >&2
        exit 2
    fi

    juno_preflight_base
    juno_define_targets

    if [[ $operation == list ]]; then
        txn_list_backups
        exit 0
    fi
    if [[ $operation == dry-run ]]; then
        juno_preflight_install readonly
        juno_validate_resources
        juno_log 'Simulação: nenhum arquivo, pacote ou serviço será alterado.'
        printf 'Atualização: sudo pacman -Syu --needed'
        printf ' %q' "${JUNO_PACKAGES[@]}"
        printf '\n'
        for target in "${JUNO_TARGETS[@]}"; do
            printf 'Gerenciado: %s/%s\n' "$JUNO_HOME" "$target"
        done
        juno_log 'Backups e diário ficarão em ~/.local/state/juno-desktop.'
        exit 0
    fi

    juno_preflight_terminal
    txn_lock
    trap 'juno_on_failure "$?" "erro na linha $LINENO"' ERR
    trap 'juno_on_exit "$?"' EXIT
    trap 'juno_on_failure 130 interrompido' INT
    trap 'juno_on_failure 143 terminado' TERM
    juno_begin_log
    txn_recover

    if [[ $operation == rollback ]]; then
        txn_restore "$backup_id"
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -fv
        fi
        txn_finalize
        juno_log 'Backup restaurado. Reinicie sua sessão do Hyprland para aplicar as alterações.'
        exit 0
    fi

    juno_preflight_install apply
    juno_validate_resources
    juno_install_packages
    juno_validate_hyprland_version
    txn_prepare
    juno_validate_staged
    if txn_changed; then
        txn_backup
        txn_apply
        fc-cache -fv
        juno_validate_installed_fonts
        txn_finalize
    else
        comparison_status=$?
        (( comparison_status == 1 )) || juno_die 'Não foi possível comparar o staging às configurações atuais.'
        txn_cleanup_stage
        juno_log 'As configurações Juno já estão atualizadas. Nenhum backup adicional foi criado.'
    fi
    juno_log 'Ambiente Juno configurado com sucesso. Reinicie sua sessão do Hyprland para aplicar as alterações.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    juno_main "$@"
fi
