#!/usr/bin/env bash
set -euo pipefail
set -E

JUNO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
readonly JUNO_ROOT
for module in common platform preflight packages validate transaction multilib applications vscode wallpapers gnome posh fonts shell; do
    # shellcheck source=/dev/null
    source "$JUNO_ROOT/lib/$module.sh"
done

usage() {
    cat <<'HELP'
Juno Desktop — instalador para Arch Linux e Zorin OS 18 (GNOME), x86_64

Uso: bash install.sh [opções]
  --dry-run         Exibe verificações e alterações previstas, sem gravar arquivos.
  --list-backups    Lista os backups deste usuário.
  --rollback ID     Restaura um backup e preserva o estado atual em outro backup.
  --with-dev-tools  No Zorin, inclui compiladores e ferramentas de desenvolvimento.
  --help            Exibe esta ajuda.

Sem opções: instala o perfil Juno com pacman (Arch) ou APT (Zorin).
No Zorin, usa o conjunto essencial; --with-dev-tools pode acompanhar --dry-run.
No Arch, a instalação inclui a atualização completa do sistema. Execute como usuário comum,
após sair da sessão gráfica e entrar em um terminal de texto (TTY).
HELP
}

juno_main() {
    local operation=install backup_id='' target comparison_status selected_operation=0
    JUNO_WITH_DEV_TOOLS=0
    while (( $# )); do
        case $1 in
            --help|-h) [[ $# -eq 1 && $selected_operation == 0 && $JUNO_WITH_DEV_TOOLS == 0 ]] || { usage >&2; exit 2; }; usage; exit 0 ;;
            --with-dev-tools)
                [[ $JUNO_WITH_DEV_TOOLS == 0 ]] || { usage >&2; exit 2; }
                JUNO_WITH_DEV_TOOLS=1
                shift
                ;;
            --dry-run|--list-backups|--rollback)
                [[ $selected_operation == 0 ]] || { usage >&2; exit 2; }
                selected_operation=1
                case $1 in
                    --dry-run) operation=dry-run; shift ;;
                    --list-backups) operation=list; shift ;;
                    --rollback)
                        [[ $# -ge 2 && $2 != --* ]] || { usage >&2; exit 2; }
                        operation=rollback; backup_id=$2; shift 2 ;;
                esac
                ;;
            *) usage >&2; exit 2 ;;
        esac
    done
    if [[ ( $operation == list || $operation == rollback ) && $JUNO_WITH_DEV_TOOLS == 1 ]]; then
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
        juno_validate_gallery
        juno_log 'Simulação: nenhum arquivo, pacote ou serviço será alterado.'
        juno_packages_plan
        juno_applications_plan
        juno_gnome_plan
        juno_log 'Terminal: Bash com Oh My Posh oficial verificado; JetBrains Mono no Kitty e VS Code. Arquivos existentes serão preservados em backup.'
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
    if [[ $operation == rollback || -e $JUNO_STATE/pending.tsv || -L $JUNO_STATE/pending.tsv ]]; then
        juno_preflight_transaction
    fi
    txn_recover

    if [[ $operation == rollback ]]; then
        txn_restore "$backup_id"
        if command -v fc-cache >/dev/null 2>&1; then
            juno_refresh_font_cache
        fi
        txn_finalize
        juno_log 'Backup restaurado. Entre novamente na sessão gráfica para aplicar as alterações.'
        exit 0
    fi

    # A legacy recovery uses its own manifest destinations. Restore the new
    # installation contract only after that recovery has completed.
    juno_define_targets
    JUNO_GSETTINGS_ENABLED=0

    juno_preflight_install apply
    juno_validate_resources
    juno_validate_gallery
    juno_install_packages
    juno_validate_gnome
    juno_install_applications
    juno_install_posh
    # Read by the transaction module loaded above.
    # shellcheck disable=SC2034
    JUNO_GSETTINGS_ENABLED=1
    txn_prepare
    juno_stage_gallery
    juno_stage_terminal
    juno_stage_fonts
    juno_validate_staged
    if txn_changed; then
        txn_backup
        txn_apply
        juno_refresh_font_cache
        juno_validate_installed_fonts
        txn_finalize
    else
        comparison_status=$?
        (( comparison_status == 1 )) || juno_die 'Não foi possível comparar o staging às configurações atuais.'
        txn_cleanup_stage
        juno_log 'As configurações Juno já estão atualizadas. Nenhum backup adicional foi criado.'
    fi
    juno_configure_gdm
    juno_log 'Ambiente Juno configurado com sucesso. Reinicie e selecione GNOME no gerenciador de login.'
    if [[ ${JUNO_SPOTIFY_SKIPPED:-0} == 1 ]]; then
        juno_warn 'Spotify não foi instalado ou atualizado nesta execução. Consulte o registro antes de tentar novamente.'
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    juno_main "$@"
fi
