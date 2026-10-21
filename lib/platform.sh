#!/usr/bin/env bash
# Read only the identifiers needed for supported systems; never source os-release.

juno_detect_platform() {
    local release=${1:-/etc/os-release} line key value os_id='' version='' codename='' ubuntu_codename=''
    local seen='|'
    [[ -f $release && -r $release ]] || juno_die 'Não foi possível ler a identificação do sistema.'
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%$'\r'}
        [[ $line =~ ^(ID|VERSION_ID|VERSION_CODENAME|UBUNTU_CODENAME)=(.*)$ ]] || continue
        key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}
        [[ $seen != *"|$key|"* ]] || juno_die "Identificação do sistema ambígua: $key repetido."
        seen+="$key|"
        case $value in
            \"*\") value=${value:1:${#value}-2} ;;
            \'*\') value=${value:1:${#value}-2} ;;
        esac
        [[ -n $value && $value =~ ^[a-zA-Z0-9._-]+$ ]] ||
            juno_die "Valor inválido na identificação do sistema: $key."
        case $key in
            ID) os_id=$value ;;
            VERSION_ID) version=$value ;;
            VERSION_CODENAME) codename=$value ;;
            UBUNTU_CODENAME) ubuntu_codename=$value ;;
        esac
    done < "$release"
    case $os_id in
        arch)
            JUNO_PLATFORM=arch
            JUNO_ZORIN_VERSION=''
            JUNO_UBUNTU_VERSION=''
            ;;
        zorin)
            [[ $version =~ ^18(\.[0-9]+)*$ ]] ||
                juno_die 'A versão Zorin suportada é 18.x com GNOME (Core/Pro), base Ubuntu 24.04.'
            [[ ${ubuntu_codename:-$codename} == noble && ( -z $codename || $codename == noble ) ]] ||
                juno_die 'A instalação Zorin exige a base Ubuntu 24.04 (noble).'
            JUNO_PLATFORM=zorin
            JUNO_ZORIN_VERSION=$version
            JUNO_UBUNTU_VERSION=24.04
            ;;
        *) juno_die 'Sistemas suportados: Arch Linux oficial e Zorin OS 18.x com GNOME (Core/Pro), x86_64.' ;;
    esac
    export JUNO_PLATFORM JUNO_ZORIN_VERSION JUNO_UBUNTU_VERSION
}

juno_platform_network_url() {
    case ${JUNO_PLATFORM:-arch} in
        arch) printf '%s\n' 'https://archlinux.org/' ;;
        zorin) printf '%s\n' 'https://zorin.com/' ;;
        *) return 1 ;;
    esac
}

juno_gdm_service() {
    case ${JUNO_PLATFORM:-arch} in
        arch) printf '%s\n' gdm.service ;;
        zorin) printf '%s\n' gdm3.service ;;
        *) return 1 ;;
    esac
}
