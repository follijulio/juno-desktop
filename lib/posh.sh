#!/usr/bin/env bash
# Verified upstream Oh My Posh, installed for this user without changing login shells.

_posh_error() { printf '[Juno · Oh My Posh] %s\n' "$*" >&2; return 1; }

_posh_fetch() {
    curl --fail --silent --show-error --location --proto '=https' \
        --proto-redir '=https' --tlsv1.2 --connect-timeout 20 --max-time 600 \
        --retry 3 --retry-delay 2 --output "$2" -- "$1"
}

_posh_metadata() {
    jq -e '
        type == "object" and .draft == false and .prerelease == false and
        (.tag_name | type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        ([.assets[]? | select(.name == "posh-linux-amd64")] | length == 1) and
        (.tag_name as $tag | [.assets[] | select(.name == "posh-linux-amd64")][0] |
            .browser_download_url == ("https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/" + $tag + "/posh-linux-amd64") and
            (.digest | type == "string" and test("^sha256:[a-f0-9]{64}$")))
    ' "$1" >/dev/null || _posh_error 'Metadados oficiais estáveis sem SHA-256 válido; download recusado.'
}

_posh_binary() {
    local executable=$1 checksum=$2 version=$3 actual
    [[ -f $executable && ! -L $executable && -x $executable ]] || {
        _posh_error 'Executável ausente ou inválido.'; return 1;
    }
    printf '%s  %s\n' "$checksum" "$executable" | sha256sum --check --status || {
        _posh_error 'Checksum SHA-256 inválido; versão atual preservada.'; return 1;
    }
    actual=$("$executable" --version) || return 1
    [[ $actual == "$version" || $actual == "v$version" ]] || {
        _posh_error 'A versão do executável diverge da release oficial.'; return 1;
    }
}

_posh_activate() {
    local app=$1 stage=$2 tag=$3
    [[ -L $app/current && $(readlink -- "$app/current") == "releases/$tag" ]] && return 0
    ln -s -- "releases/$tag" "$stage/current" || return 1
    mv -fT -- "$stage/current" "$app/current"
}

juno_install_posh() (
    set -euo pipefail
    umask 077
    local app stage='' metadata tag version checksum url release current_target
    _txn_require_lock || return 1
    juno_require curl jq sha256sum
    _txn_mkdir_home '.local/share/juno-apps/oh-my-posh/releases' || return 1
    app=$(realpath -e -- "$JUNO_HOME/.local/share/juno-apps/oh-my-posh") || return 1
    [[ ! -L $JUNO_HOME/.local/share/juno-apps/oh-my-posh && ! -L $app/releases ]] || {
        _posh_error 'O diretório do Oh My Posh e releases precisam ser diretórios reais.'; return 1;
    }
    chmod 700 -- "$app" "$app/releases" || return 1
    if [[ -e $app/current || -L $app/current ]]; then
        [[ -L $app/current ]] || { _posh_error 'current precisa ser um link gerenciado pelo Juno.'; return 1; }
        current_target=$(readlink -- "$app/current") || return 1
        [[ $current_target =~ ^releases/v[0-9]+\.[0-9]+\.[0-9]+$ && -d $app/$current_target && ! -L $app/$current_target ]] || {
            _posh_error 'O link atual do Oh My Posh aponta para uma versão inválida.'; return 1;
        }
    fi
    stage=$(mktemp -d "$app/.download.XXXXXXXX") || return 1
    trap '[[ -z "$stage" ]] || rm -rf -- "$stage"' EXIT
    chmod 700 -- "$stage" || return 1
    metadata="$stage/metadata.json"
    juno_log 'Consultando a release estável oficial do Oh My Posh no GitHub.'
    _posh_fetch 'https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/releases/latest' "$metadata" || return 1
    _posh_metadata "$metadata" || return 1
    tag=$(jq -r .tag_name "$metadata")
    version=${tag#v}
    checksum=$(jq -r '.assets[] | select(.name == "posh-linux-amd64") | .digest | ltrimstr("sha256:")' "$metadata")
    url=$(jq -r '.assets[] | select(.name == "posh-linux-amd64") | .browser_download_url' "$metadata")
    release="$app/releases/$tag"
    if [[ -e $release || -L $release ]]; then
        [[ -d $release && ! -L $release && -f $release/.juno-posh.json && ! -L $release/.juno-posh.json ]] || {
            _posh_error 'A versão existente não possui manifesto Juno válido.'; return 1;
        }
        _posh_metadata "$release/.juno-posh.json" || return 1
        jq -e --arg tag "$tag" --arg checksum "sha256:$checksum" \
            '.tag_name == $tag and ([.assets[] | select(.name == "posh-linux-amd64")][0].digest == $checksum)' \
            "$release/.juno-posh.json" >/dev/null || {
            _posh_error 'O manifesto instalado diverge da release oficial.'; return 1;
        }
        _posh_binary "$release/oh-my-posh" "$checksum" "$version" || return 1
        juno_log "Oh My Posh $version já instalado; download do binário dispensado."
    else
        mkdir -- "$stage/release" || return 1
        _posh_fetch "$url" "$stage/release/oh-my-posh" || return 1
        chmod 755 -- "$stage/release/oh-my-posh" || return 1
        _posh_binary "$stage/release/oh-my-posh" "$checksum" "$version" || return 1
        cp -- "$metadata" "$stage/release/.juno-posh.json" || return 1
        chmod 600 -- "$stage/release/.juno-posh.json" || return 1
        sync -f "$stage/release" || return 1
        mv -T -- "$stage/release" "$release" || return 1
        sync -f "$app/releases" || return 1
    fi
    # Last operation: never switch current before every download and check succeeds.
    _posh_activate "$app" "$stage" "$tag" || return 1
    juno_log "Oh My Posh $version pronto. Releases anteriores mantidas em $app/releases."
)
