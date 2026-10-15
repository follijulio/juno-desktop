#!/usr/bin/env bash
# Original Microsoft build, installed without root privileges or AUR helpers.

_vscode_error() { printf '[Juno · VS Code] %s\n' "$*" >&2; return 1; }

_vscode_fetch() {
    curl --fail --silent --show-error --location --proto '=https' \
        --proto-redir '=https' --tlsv1.2 --connect-timeout 20 --max-time 600 \
        --retry 3 --retry-delay 2 --output "$2" -- "$1"
}

_vscode_metadata() {
    jq -e '
        type == "object" and
        (.productVersion | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
        (.version | type == "string" and test("^[a-f0-9]{40}$")) and
        (.sha256hash | type == "string" and test("^[a-f0-9]{64}$")) and
        (.url | type == "string" and test("^https://vscode\\.download\\.prss\\.microsoft\\.com/[^\\s]+$"))
    ' "$1" >/dev/null || _vscode_error 'Metadados estáveis da Microsoft inválidos; download recusado.'
}

_vscode_archive() {
    # Inspect before GNU tar sees any member. In particular, a link must never
    # become an ancestor of another entry or point outside the release tree.
    python3 - "$1" <<'PY'
import posixpath
import sys
import tarfile

root = "VSCode-linux-x64"
try:
    with tarfile.open(sys.argv[1], "r:gz") as archive:
        members = archive.getmembers()
        if not members:
            raise ValueError("arquivo vazio")
        links = set()
        names = set()
        for member in members:
            name = member.name.rstrip("/")
            if (not name or name.startswith("/") or "\\" in name
                    or any(ord(c) < 32 for c in name)
                    or any(p in ("", ".", "..") for p in name.split("/"))
                    or not (name == root or name.startswith(root + "/"))):
                raise ValueError("caminho inválido: " + repr(name))
            if name in names:
                raise ValueError("membro repetido: " + name)
            names.add(name)
            if not (member.isfile() or member.isdir() or member.issym() or member.islnk()):
                raise ValueError("arquivo especial: " + name)
            if member.issym() or member.islnk():
                target = member.linkname
                if not target or target.startswith("/") or "\\" in target or any(ord(c) < 32 for c in target):
                    raise ValueError("link inválido: " + name)
                resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), target) if member.issym() else target)
                if not resolved.startswith(root + "/"):
                    raise ValueError("link fora do aplicativo: " + name)
                links.add(name)
        for name in names:
            parent = posixpath.dirname(name)
            while parent:
                if parent in links:
                    raise ValueError("link usado como diretório: " + parent)
                parent = posixpath.dirname(parent)
except (OSError, tarfile.TarError, ValueError) as exc:
    print("Arquivo VS Code recusado: " + str(exc), file=sys.stderr)
    sys.exit(1)
PY
}

_vscode_product() {
    local release=$1 expected_version=$2
    [[ -f "$release/code" && -x "$release/code" && ! -L "$release/code" &&
       -f "$release/bin/code" && -x "$release/bin/code" && ! -L "$release/bin/code" &&
       -f "$release/resources/app/product.json" && ! -L "$release/resources/app/product.json" &&
       -f "$release/resources/app/package.json" && ! -L "$release/resources/app/package.json" &&
       -f "$release/resources/app/resources/linux/code.png" ]] || {
        _vscode_error 'O pacote não contém os executáveis e recursos esperados.'; return 1;
    }
    jq -e '.nameLong == "Visual Studio Code" and .applicationName == "code"' \
        "$release/resources/app/product.json" >/dev/null || {
        _vscode_error 'Identidade inválida: é obrigatório o Visual Studio Code original da Microsoft.'; return 1;
    }
    jq -e --arg version "$expected_version" '.version == $version' \
        "$release/resources/app/package.json" >/dev/null || {
        _vscode_error 'A versão do aplicativo diverge dos metadados da Microsoft.'; return 1;
    }
}

_vscode_shell_quote() {
    local value=$1
    value=${value//\'/\'\\\'\'}
    printf "'%s'" "$value"
}

_vscode_desktop_string() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

_vscode_desktop_exec() {
    local value=$1
    # Desktop Exec has both the desktop-string and command-argument escaping
    # layers. Percent is a field-code marker even within double quotes.
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//\`/\\\`}
    value=${value//\$/\\\$}
    value=${value//%/%%}
    printf '"%s"' "$(_vscode_desktop_string "$value")"
}

_vscode_launchers() {
    local stage=$1 app=$2 wrapper desktop backup='' destination name
    wrapper="$JUNO_HOME/.local/bin/code"
    desktop="$JUNO_HOME/.local/share/applications/juno-vscode.desktop"
    _txn_mkdir_home '.local/bin' || return 1
    _txn_mkdir_home '.local/share/applications' || return 1
    printf '#!/usr/bin/env bash\n# Gerenciado por Juno Desktop: VS Code Microsoft.\nexec %s "$@"\n' \
        "$(_vscode_shell_quote "$app/current/bin/code")" >"$stage/code" || return 1
    {
        printf '[Desktop Entry]\nVersion=1.0\nType=Application\nName=Visual Studio Code\n'
        printf 'Comment=Editor de código da Microsoft\n'
        printf 'Exec=%s %%F\n' "$(_vscode_desktop_exec "$wrapper")"
        printf 'TryExec=%s\n' "$(_vscode_desktop_string "$wrapper")"
        printf 'Icon=%s\n' "$(_vscode_desktop_string "$app/current/resources/app/resources/linux/code.png")"
        printf 'Terminal=false\nCategories=Development;IDE;TextEditor;\nStartupWMClass=Code\n'
        printf 'X-Juno-Managed=true\n'
    } >"$stage/juno-vscode.desktop" || return 1
    chmod 755 -- "$stage/code" || return 1
    chmod 644 -- "$stage/juno-vscode.desktop" || return 1
    for name in code juno-vscode.desktop; do
        destination=$wrapper
        [[ $name == code ]] || destination=$desktop
        if [[ -e $destination || -L $destination ]]; then
            [[ -f $destination || -L $destination ]] || {
                _vscode_error "Launcher existente não é arquivo/link: $destination"; return 1;
            }
            if [[ ! -L $destination ]] && cmp -s -- "$stage/$name" "$destination" &&
                [[ $(stat -c %a -- "$destination") == "$(stat -c %a -- "$stage/$name")" ]]; then
                continue
            fi
            if [[ -z $backup ]]; then
                _txn_mkdir_home '.local/state/juno-desktop/apps/backups' || return 1
                [[ ! -L "$JUNO_STATE/apps/backups" ]] || return 1
                backup=$(mktemp -d "$JUNO_STATE/apps/backups/vscode-$(date -u +%Y%m%dT%H%M%SZ).XXXXXXXX") || return 1
                chmod 700 -- "$backup" || return 1
            fi
            cp -a -- "$destination" "$backup/$name" || return 1
        fi
        # Stage beside each destination so replacing a launcher stays atomic
        # even when .local/bin and the app are on distinct filesystems.
        local temporary
        temporary=$(mktemp "${destination%/*}/.juno-vscode.XXXXXXXX") || return 1
        if cp -- "$stage/$name" "$temporary" && chmod --reference="$stage/$name" -- "$temporary" &&
            mv -fT -- "$temporary" "$destination"; then :; else
            rm -f -- "$temporary"
            return 1
        fi
    done
    [[ -z $backup ]] || juno_log "Launchers anteriores do VS Code preservados em: $backup"
}

_vscode_activate() {
    local app=$1 stage=$2 commit=$3
    if [[ ! -L "$app/current" || $(readlink -- "$app/current") != "releases/$commit" ]]; then
        ln -s -- "releases/$commit" "$stage/current" || return 1
        mv -fT -- "$stage/current" "$app/current" || return 1
    fi
}

juno_install_vscode() (
    set -euo pipefail
    umask 077
    local app stage='' metadata commit version checksum url release current_target
    _txn_require_lock || return 1
    juno_require curl jq python3 tar sha256sum
    _txn_mkdir_home '.local/share/juno-apps/vscode/releases' || return 1
    app=$(realpath -e -- "$JUNO_HOME/.local/share/juno-apps/vscode") || return 1
    [[ ! -L "$JUNO_HOME/.local/share/juno-apps/vscode" && ! -L "$app/releases" ]] || {
        _vscode_error 'O diretório do VS Code e releases precisam ser diretórios reais.'; return 1;
    }
    if [[ -e "$app/current" || -L "$app/current" ]]; then
        [[ -L "$app/current" ]] || { _vscode_error 'current precisa ser um link gerenciado pelo Juno.'; return 1; }
        current_target=$(readlink -- "$app/current") || return 1
        [[ $current_target =~ ^releases/[a-f0-9]{40}$ && -d "$app/$current_target" && ! -L "$app/$current_target" ]] || {
            _vscode_error 'O link atual do VS Code aponta para uma versão inválida.'; return 1;
        }
    fi
    juno_private_subdir apps
    stage=$(mktemp -d "$app/.download.XXXXXXXX") || return 1
    trap '[[ -z "$stage" ]] || rm -rf -- "$stage"' EXIT
    chmod 700 -- "$stage" || return 1
    metadata="$stage/metadata.json"
    juno_log 'Consultando a versão estável original do Visual Studio Code na Microsoft.'
    _vscode_fetch 'https://update.code.visualstudio.com/api/update/linux-x64/stable/latest' "$metadata" || return 1
    _vscode_metadata "$metadata" || return 1
    commit=$(jq -r .version "$metadata")
    version=$(jq -r .productVersion "$metadata")
    checksum=$(jq -r .sha256hash "$metadata")
    url=$(jq -r .url "$metadata")
    release="$app/releases/$commit"
    if [[ -e $release || -L $release ]]; then
        [[ -d $release && ! -L $release && -f "$release/.juno-vscode.json" && ! -L "$release/.juno-vscode.json" ]] || {
            _vscode_error 'A versão existente não possui um manifesto Juno válido.'; return 1;
        }
        jq -e --arg commit "$commit" --arg checksum "$checksum" --arg version "$version" \
            '.version == $commit and .sha256hash == $checksum and .productVersion == $version' \
            "$release/.juno-vscode.json" >/dev/null || {
            _vscode_error 'O manifesto da versão instalada não corresponde ao download original.'; return 1;
        }
        _vscode_product "$release" "$version" || return 1
        juno_log "Visual Studio Code $version já instalado; download do binário dispensado."
    else
        juno_log "Baixando Visual Studio Code $version (Microsoft, linux-x64)."
        _vscode_fetch "$url" "$stage/vscode.tar.gz" || return 1
        printf '%s  %s\n' "$checksum" "$stage/vscode.tar.gz" | sha256sum --check --status || {
            _vscode_error 'Checksum SHA-256 inválido; versão atual preservada.'; return 1;
        }
        _vscode_archive "$stage/vscode.tar.gz" || return 1
        mkdir -- "$stage/unpack" || return 1
        tar --extract --gzip --file "$stage/vscode.tar.gz" --directory "$stage/unpack" \
            --no-same-owner --no-same-permissions || return 1
        _vscode_product "$stage/unpack/VSCode-linux-x64" "$version" || return 1
        cp -- "$metadata" "$stage/unpack/VSCode-linux-x64/.juno-vscode.json" || return 1
        mv -T -- "$stage/unpack/VSCode-linux-x64" "$release" || return 1
    fi
    _vscode_launchers "$stage" "$app" || return 1
    _vscode_activate "$app" "$stage" "$commit" || return 1
    cp -- "$metadata" "$stage/installed.json" || return 1
    chmod 600 -- "$stage/installed.json" || return 1
    mv -fT -- "$stage/installed.json" "$JUNO_STATE/apps/vscode.json" || return 1
    juno_log "Visual Studio Code original $version pronto. Versões anteriores foram mantidas em $app/releases."
)
