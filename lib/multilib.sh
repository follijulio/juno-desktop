#!/usr/bin/env bash
# O Steam usa o repositório oficial multilib. Não habilita repositórios de teste.

_juno_multilib_error() {
    printf '[Juno · erro] multilib: %s\n' "$*" >&2
    return 1
}

_juno_multilib_has_repo() {
    local repositories=$1 repository
    while IFS= read -r repository; do
        [[ $repository == multilib ]] && return 0
    done <<< "$repositories"
    return 1
}

# Transformação isolada: recebe arquivos explícitos e preserva o conteúdo original.
# As entradas comentadas e multilib-testing não contam como multilib ativo.
juno_multilib_render() {
    local input=$1 output=$2
    [[ -f $input && ! -L $input ]] || { _juno_multilib_error 'origem inválida'; return 1; }
    [[ ! -L $output && ( ! -e $output || -f $output ) ]] || { _juno_multilib_error 'destino inválido'; return 1; }
    [[ $input != "$output" && ! $input -ef $output ]] || { _juno_multilib_error 'origem e destino precisam ser diferentes'; return 1; }
    cat -- "$input" > "$output" || return 1
    if ! awk '
        /^[[:space:]]*\[multilib\][[:space:]]*(#.*)?$/ { found = 1 }
        END { exit !found }
    ' "$input"; then
        printf '\n# Juno Desktop: Steam e bibliotecas oficiais de 32 bits.\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> "$output" || return 1
    fi
}

_juno_multilib_validate_stage() {
    local repositories
    repositories=$(pacman-conf --config "$1" --repo-list) || {
        _juno_multilib_error 'o pacman-conf rejeitou a configuração preparada'
        return 1
    }
    _juno_multilib_has_repo "$repositories" || {
        _juno_multilib_error 'a configuração preparada não habilita multilib'
        return 1
    }
}

juno_multilib_plan() {
    local repositories
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        juno_log 'Zorin: Steam via Flatpak; arquiteturas dpkg e repositórios APT existentes serão preservados.'
        return 0
    fi
    juno_require pacman-conf
    repositories=$(pacman-conf --config /etc/pacman.conf --repo-list) ||
        juno_die 'Não foi possível consultar os repositórios do pacman.'
    if _juno_multilib_has_repo "$repositories"; then
        juno_log 'Steam: o repositório oficial multilib já está ativo.'
    else
        juno_log 'Steam: será criado um backup de /etc/pacman.conf e habilitado apenas multilib, antes da atualização completa.'
    fi
}

_juno_multilib_config_safe() {
    local config=/etc/pacman.conf mode
    [[ -f $config && ! -L $config && $(realpath -e -- "$config") == "$config" ]] || {
        _juno_multilib_error '/etc/pacman.conf precisa ser um arquivo regular sem links simbólicos'
        return 1
    }
    [[ $(stat -c %u -- "$config") == 0 && $(stat -c %h -- "$config") == 1 ]] || {
        _juno_multilib_error '/etc/pacman.conf precisa pertencer a root e não possuir links adicionais'
        return 1
    }
    mode=$(stat -c %a -- "$config") || return 1
    (( (8#$mode & 0022) == 0 )) || {
        _juno_multilib_error '/etc/pacman.conf não pode permitir escrita de grupo ou outros usuários'
        return 1
    }
}

_juno_multilib_cleanup() {
    local user_directory=$1 privileged_file=${2:-} prefix suffix
    if [[ -n $privileged_file ]]; then
        if [[ $privileged_file =~ ^/etc/\.juno-pacman\.[[:alnum:]]{8}$ ]]; then
            sudo rm -f -- "$privileged_file" || juno_warn "Remova o temporário após verificar seu conteúdo: $privileged_file"
        else
            juno_warn 'Caminho temporário privilegiado inesperado; preservado para revisão.'
        fi
    fi
    prefix="$JUNO_STATE/packages/.multilib-stage."
    suffix=${user_directory#"$prefix"}
    if [[ $user_directory == "$prefix"* && $suffix =~ ^[[:alnum:]]{8}$ && ! -L $user_directory ]]; then
        rm -rf -- "$user_directory" || juno_warn "Remova o staging após verificar seu conteúdo: $user_directory"
    else
        juno_warn 'Caminho temporário de multilib inesperado; preservado para revisão.'
    fi
    return 0
}

juno_enable_multilib() {
    local repositories config=/etc/pacman.conf workdir original_digest current_digest
    local original_identity current_identity backup backup_digest privileged_file='' mode group
    if [[ ${JUNO_PLATFORM:-arch} == zorin ]]; then
        juno_log 'Zorin: nenhuma alteração de multilib ou arquiteturas dpkg é necessária para Steam via Flatpak.'
        return 0
    fi
    juno_require pacman-conf install
    repositories=$(pacman-conf --config "$config" --repo-list) ||
        juno_die 'Não foi possível consultar os repositórios do pacman.'
    if _juno_multilib_has_repo "$repositories"; then
        juno_log 'O repositório oficial multilib já está ativo.'
        return 0
    fi
    _juno_multilib_config_safe || juno_die 'Habilitação automática de multilib interrompida; revise /etc/pacman.conf.'
    original_digest=$(sha256sum -- "$config") || juno_die 'Não foi possível ler /etc/pacman.conf.'
    original_identity=$(stat -c '%d:%i:%u:%g:%a:%h' -- "$config") || juno_die 'Não foi possível inspecionar /etc/pacman.conf.'
    mode=$(stat -c %a -- "$config") || juno_die 'Não foi possível ler as permissões do pacman.'
    group=$(stat -c %g -- "$config") || juno_die 'Não foi possível ler o grupo do pacman.'
    juno_private_subdir packages
    workdir=$(mktemp -d "$JUNO_STATE/packages/.multilib-stage.XXXXXXXX") || juno_die 'Não foi possível preparar multilib.'
    chmod 700 -- "$workdir"
    if ! juno_multilib_render "$config" "$workdir/pacman.conf" || ! _juno_multilib_validate_stage "$workdir/pacman.conf"; then
        _juno_multilib_cleanup "$workdir"
        juno_die 'Configuração de multilib inválida; /etc/pacman.conf permanece preservado.'
    fi
    backup="$config.juno-$(date -u +%Y%m%dT%H%M%SZ)-$$.bak"
    sudo -v || { _juno_multilib_cleanup "$workdir"; juno_die 'Não foi possível obter sudo para habilitar multilib.'; }
    if [[ -e $backup || -L $backup ]] || ! sudo cp -a -- "$config" "$backup"; then
        _juno_multilib_cleanup "$workdir"
        juno_die 'Não foi possível preservar um backup exclusivo do pacman; nenhuma substituição foi realizada.'
    fi
    juno_log "Backup da configuração do pacman: $backup"
    backup_digest=$(sudo sha256sum -- "$backup") || backup_digest=''
    if [[ ${backup_digest%% *} != "${original_digest%% *}" ]]; then
        _juno_multilib_cleanup "$workdir"
        juno_die "O backup do pacman não corresponde ao original; nenhuma substituição foi realizada. Preserve: $backup"
    fi
    privileged_file=$(sudo mktemp /etc/.juno-pacman.XXXXXXXX) || {
        _juno_multilib_cleanup "$workdir"
        juno_die "Não foi possível preparar a substituição do pacman. Backup: $backup"
    }
    if [[ ! $privileged_file =~ ^/etc/\.juno-pacman\.[[:alnum:]]{8}$ ]] ||
        ! sudo install -o root -g "$group" -m "$mode" -- "$workdir/pacman.conf" "$privileged_file"; then
        _juno_multilib_cleanup "$workdir" "$privileged_file"
        juno_die "Não foi possível preparar a configuração privilegiada. Backup: $backup"
    fi
    if ! _juno_multilib_config_safe; then
        _juno_multilib_cleanup "$workdir" "$privileged_file"
        juno_die "O arquivo do pacman mudou durante a preparação; preservado para revisão. Backup: $backup"
    fi
    current_digest=$(sha256sum -- "$config") || current_digest=''
    current_identity=$(stat -c '%d:%i:%u:%g:%a:%h' -- "$config") || current_identity=''
    if [[ $current_digest != "$original_digest" || $current_identity != "$original_identity" ]]; then
        _juno_multilib_cleanup "$workdir" "$privileged_file"
        juno_die "O arquivo do pacman mudou durante a preparação; nenhuma substituição foi realizada. Backup: $backup"
    fi
    if ! sudo mv -T -- "$privileged_file" "$config"; then
        _juno_multilib_cleanup "$workdir" "$privileged_file"
        juno_die "Falha ao habilitar multilib. Preserve e revise o backup: $backup"
    fi
    _juno_multilib_cleanup "$workdir"
    juno_log 'Repositório oficial multilib habilitado. O próximo passo executará pacman -Syu; nenhuma sincronização parcial foi realizada.'
}
