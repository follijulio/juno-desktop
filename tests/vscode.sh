#!/usr/bin/env bash
set -euo pipefail

TEST_REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/juno-vscode-tests.XXXXXXXX")
TEST_ROOT=$(realpath -e -- "$TEST_ROOT")
trap '[[ -n "$TEST_ROOT" && "$TEST_ROOT" != / && "${TEST_ROOT##*/}" == juno-vscode-tests.* ]] && rm -rf -- "$TEST_ROOT"' EXIT
mkdir -- "$TEST_ROOT/mock-bin"
cat >"$TEST_ROOT/mock-bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
output=''
while (($#)); do
    case $1 in
        --output) output=$2; shift 2;;
        --) shift; break;;
        *) shift;;
    esac
done
[[ -n $output && $# == 1 ]] || exit 64
printf '%s\n' "$1" >>"$TEST_CURL_LOG"
case $1 in
    https://update.code.visualstudio.com/api/update/linux-x64/stable/latest|https://update.code.visualstudio.com/api/update/linux-deb-x64/stable/latest)
        [[ ${TEST_OFFLINE:-0} == 0 ]] || exit 6
        cp -- "$TEST_METADATA" "$output";;
    https://vscode.download.prss.microsoft.com/*)
        [[ ${TEST_BINARY_FAIL:-0} == 0 ]] || exit 22
        cp -- "$TEST_ARCHIVE" "$output";;
    *) exit 65;;
esac
MOCK
chmod +x -- "$TEST_ROOT/mock-bin/curl"
export PATH="$TEST_ROOT/mock-bin:$TEST_REPO/.cache/qa/bin:$PATH"
source "$TEST_REPO/lib/common.sh"
source "$TEST_REPO/lib/transaction.sh"
source "$TEST_REPO/lib/vscode.sh"

# MSYS skips conversion of paths containing an apostrophe for native binaries.
# Translate only file arguments in this test harness, preserving literal jq
# filters and testing the Linux installer's shell quoting without alteration.
if [[ $(uname -s) == MINGW* || $(uname -s) == MSYS* ]]; then
    TEST_REAL_JQ=$(command -v jq)
    TEST_REAL_PYTHON=$(command -v python3)
    _test_native() {
        local executable=$1 argument
        shift
        local -a arguments=()
        for argument in "$@"; do
            if [[ $argument == /* && -d $(dirname -- "$argument") ]]; then
                argument=$(cygpath -m -- "$argument")
            fi
            arguments+=("$argument")
        done
        MSYS2_ARG_CONV_EXCL='*' "$executable" "${arguments[@]}"
    }
    jq() { _test_native "$TEST_REAL_JQ" "$@"; }
    python3() { _test_native "$TEST_REAL_PYTHON" "$@"; }
fi

# Git Bash cannot create genuine symlinks on this Windows host. Keep the actual
# activation implementation on Linux; Windows checks all downloads, validation,
# release retention and launcher behavior with only activation mocked.
TEST_NATIVE_LINKS=1
mkdir -- "$TEST_ROOT/link-target"
if MSYS=winsymlinks:nativestrict ln -s link-target "$TEST_ROOT/link-probe" 2>/dev/null && [[ -L "$TEST_ROOT/link-probe" ]]; then
    export MSYS=winsymlinks:nativestrict
else
    TEST_NATIVE_LINKS=0
    _vscode_activate() { printf '%s\n' "$3" >"$1/.mock-current"; }
    printf 'AVISO: ativação por symlink simulada; teste nativo continua obrigatório.\n'
fi

fail() { printf 'FALHOU: %s\n' "$*" >&2; return 1; }
expect_absent() { [[ ! -e $1 && ! -L $1 ]] || fail "caminho deveria estar ausente: $1"; }
fixture() {
    CASE_ROOT=$(mktemp -d "$TEST_ROOT/case.XXXXXXXX")
    mkdir -- "$CASE_ROOT/home O'Neil % cash\$"
    JUNO_HOME=$(realpath -e -- "$CASE_ROOT/home O'Neil % cash\$")
    JUNO_STATE="$JUNO_HOME/.local/state/juno-desktop"
    JUNO_LOCK_HELD=1
    TEST_COMMIT=1111111111111111111111111111111111111111
    TEST_VERSION=1.2.3
    TEST_ARCHIVE="$CASE_ROOT/vendor.tar.gz"
    TEST_METADATA="$CASE_ROOT/metadata.json"
    TEST_CURL_LOG="$CASE_ROOT/downloads"
    TEST_CODE_ARGS="$CASE_ROOT/code-args"
    : >"$TEST_CURL_LOG"
    TEST_OFFLINE=0 TEST_BINARY_FAIL=0
    JUNO_PLATFORM=arch
    export TEST_ARCHIVE TEST_METADATA TEST_CURL_LOG TEST_OFFLINE TEST_BINARY_FAIL TEST_CODE_ARGS
    # The real helper's allowlist is extended to apps in the main installer.
    _txn_mkdir_home '.local/state/juno-desktop/apps'
    make_archive original
}

debian_fixture() {
    fixture
    JUNO_PLATFORM=zorin
    TEST_NATIVE_ROOT="$CASE_ROOT/native-code"
    TEST_NATIVE_ARCHIVE=$TEST_ARCHIVE
    TEST_APT_LOG="$CASE_ROOT/apt-calls"
    TEST_DPKG_STATE="$CASE_ROOT/dpkg-state"
    TEST_APT_FAIL=0
    TEST_GLOBAL_LAUNCHER="$CASE_ROOT/global-code"
    TEST_ARCHIVE="$CASE_ROOT/vendor.deb"
    : > "$TEST_APT_LOG"
    make_debian code amd64 "$TEST_VERSION-1234567890"
    _vscode_native_root() { printf '%s' "$TEST_NATIVE_ROOT"; }
    _vscode_legacy_system_launcher() { printf '%s' "$TEST_GLOBAL_LAUNCHER"; }
    dpkg-query() { [[ -f $TEST_DPKG_STATE ]] && cat -- "$TEST_DPKG_STATE"; }
    dpkg-deb() {
        [[ $1 == --field ]] || return 99
        jq -er --arg field "$3" '.[$field] | strings' "$2"
    }
    dpkg() {
        [[ $1 == --compare-versions && $3 == ge ]] || return 99
        python3 - "$2" "$4" <<'PY'
import sys
def version(value):
    return tuple(map(int, value.split("-", 1)[0].split(".")))
sys.exit(0 if version(sys.argv[1]) >= version(sys.argv[2]) else 1)
PY
    }
    # sudo is replaced below, so these functions remain entirely unprivileged.
    # shellcheck disable=SC2032,SC2329
    debconf-set-selections() { cat >> "$TEST_APT_LOG"; }
    # shellcheck disable=SC2032,SC2329
    apt-get() {
        printf '%s\n' "$*" >> "$TEST_APT_LOG"
        [[ $TEST_APT_FAIL == 0 ]] || return 100
        [[ $* == "install --no-install-recommends --no-remove -- "* ]] || return 99
        mkdir -p -- "$TEST_NATIVE_ROOT"
        tar --extract --gzip --file "$TEST_NATIVE_ARCHIVE" --directory "$TEST_NATIVE_ROOT" --strip-components=1
        printf 'installed\tamd64\t%s-1234567890\n' "$TEST_VERSION" > "$TEST_DPKG_STATE"
    }
    sudo() { "$@"; }
}

make_debian() {
    jq -n --arg package "$1" --arg arch "$2" --arg version "$3" \
        '{Package:$package,Architecture:$arch,Version:$version}' > "$TEST_ARCHIVE"
    metadata
}
make_archive() {
    local kind=$1
    python3 - "$TEST_ARCHIVE" "$kind" "$TEST_VERSION" <<'PY'
import io
import json
import sys
import tarfile

filename, kind, version = sys.argv[1:]
root = "VSCode-linux-x64"
product = {"nameLong": "Visual Studio Code", "applicationName": "code"}
if kind == "oss":
    product = {"nameLong": "Code - OSS", "applicationName": "code-oss"}
files = {
    "code": b"#!/usr/bin/env bash\nexit 0\n",
    "bin/code": b'#!/usr/bin/env bash\nprintf "%s\\0" "$@" >"$TEST_CODE_ARGS"\n',
    "resources/app/product.json": json.dumps(product).encode(),
    "resources/app/package.json": json.dumps({"version": version if kind != "version" else "0.0.0"}).encode(),
    "resources/app/resources/linux/code.png": ("image fixture " + version).encode(),
}
with tarfile.open(filename, "w:gz") as archive:
    for name, body in files.items():
        info = tarfile.TarInfo(root + "/" + name)
        info.mode = 0o755 if name in ("code", "bin/code") else 0o644
        info.size = len(body)
        archive.addfile(info, io.BytesIO(body))
    if kind in ("traversal", "absolute", "special", "link", "link-parent"):
        info = tarfile.TarInfo(root + "/../escape" if kind == "traversal" else root + "/extra")
        if kind == "absolute":
            info.name = "/escape"
        if kind == "special":
            info.type = tarfile.FIFOTYPE
        if kind in ("link", "link-parent"):
            info.type = tarfile.SYMTYPE
            info.linkname = "../../outside" if kind == "link" else "resources/app"
        archive.addfile(info)
        if kind == "link-parent":
            child = tarfile.TarInfo(root + "/extra/nested")
            archive.addfile(child)
PY
    metadata
}
metadata() {
    local checksum
    checksum=$(sha256sum "$TEST_ARCHIVE"); checksum=${checksum%% *}
    jq -n --arg version "$TEST_VERSION" --arg commit "$TEST_COMMIT" --arg sha "$checksum" \
        '{productVersion:$version,version:$commit,sha256hash:$sha,url:"https://vscode.download.prss.microsoft.com/dbazure/download/stable/vendor.tar.gz"}' >"$TEST_METADATA"
}
app_path() { printf '%s/.local/share/juno-apps/vscode' "$JUNO_HOME"; }
icon_path() { printf '%s/.local/share/icons/hicolor/256x256/apps/visual-studio-code.png' "$JUNO_HOME"; }
current_commit() {
    if ((TEST_NATIVE_LINKS)); then
        local target
        target=$(readlink -- "$(app_path)/current")
        printf '%s' "${target#releases/}"
    else
        cat -- "$(app_path)/.mock-current"
    fi
}
expect_no_stages() {
    local found
    found=$(find "$(app_path)" -maxdepth 1 -name '.download.*' -print -quit)
    [[ -z $found ]] || fail 'área privada não foi removida'
}

test_install() {
    fixture
    juno_install_vscode
    [[ $(current_commit) == "$TEST_COMMIT" ]] || fail 'versão não ativada'
    [[ -f "$(app_path)/releases/$TEST_COMMIT/.juno-vscode.json" ]] || fail 'manifesto ausente'
    [[ -x "$JUNO_HOME/.local/bin/code" && -f "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" ]] || fail 'launchers ausentes'
    grep -qx 'Icon=visual-studio-code' "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" || fail 'launcher não permite resolução pelo tema de ícones'
    cmp -s -- "$(icon_path)" "$(app_path)/releases/$TEST_COMMIT/resources/app/resources/linux/code.png" || fail 'fallback hicolor não preservou o ícone original da Microsoft'
    jq -e --arg version "$TEST_VERSION" '.productVersion == $version' "$JUNO_STATE/apps/vscode.json" >/dev/null
    [[ $(wc -l <"$TEST_CURL_LOG") == 2 ]] || fail 'número incorreto de downloads'
    expect_no_stages
}
test_idempotence() {
    fixture
    juno_install_vscode
    juno_install_vscode
    [[ $(wc -l <"$TEST_CURL_LOG") == 3 ]] || fail 'versão idêntica baixou outro binário'
    [[ ! -d "$JUNO_STATE/apps/backups" ]] || fail 'launchers idênticos criaram backup'
    expect_no_stages
}
test_update_retains_previous() {
    fixture
    juno_install_vscode
    local previous=$TEST_COMMIT
    TEST_COMMIT=2222222222222222222222222222222222222222
    TEST_VERSION=1.2.4
    make_archive original
    juno_install_vscode
    [[ $(current_commit) == "$TEST_COMMIT" && -d "$(app_path)/releases/$previous" ]] || fail 'atualização perdeu a versão anterior'
    cmp -s -- "$(icon_path)" "$(app_path)/releases/$TEST_COMMIT/resources/app/resources/linux/code.png" || fail 'fallback hicolor não acompanhou a release'
    local backup
    backup=$(find "$JUNO_STATE/apps/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    cmp -s -- "$backup/visual-studio-code.png" "$(app_path)/releases/$previous/resources/app/resources/linux/code.png" || fail 'ícone da release anterior não foi preservado'
    expect_no_stages
}
test_corrupt_preserves_current() {
    fixture
    juno_install_vscode
    local previous=$TEST_COMMIT
    TEST_COMMIT=2222222222222222222222222222222222222222
    metadata
    printf 'corrompido\n' >>"$TEST_ARCHIVE"
    if juno_install_vscode; then fail 'checksum inválido foi aceito'; fi
    [[ $(current_commit) == "$previous" ]] || fail 'falha alterou a versão atual'
    cmp -s -- "$(icon_path)" "$(app_path)/releases/$previous/resources/app/resources/linux/code.png" || fail 'falha no download alterou o ícone existente'
    expect_absent "$(app_path)/releases/$TEST_COMMIT"
    expect_no_stages
}
test_failed_binary() {
    fixture
    TEST_BINARY_FAIL=1
    if juno_install_vscode; then fail 'falha de download foi ignorada'; fi
    expect_absent "$(app_path)/releases/$TEST_COMMIT"
    expect_no_stages
}
test_offline() {
    fixture
    TEST_OFFLINE=1
    if juno_install_vscode; then fail 'instalação offline foi aceita'; fi
    expect_absent "$JUNO_HOME/.local/bin/code"
    expect_no_stages
}
test_untrusted_metadata() {
    local field value
    for field in url version sha256hash productVersion; do
        fixture
        case $field in
            url) value='https://vscode.download.prss.microsoft.com.evil.invalid/payload';;
            *) value='../escape';;
        esac
        jq --arg key "$field" --arg value "$value" '.[$key]=$value' "$TEST_METADATA" >"$CASE_ROOT/changed.json"
        mv -- "$CASE_ROOT/changed.json" "$TEST_METADATA"
        if juno_install_vscode; then fail "metadado inválido aceito: $field"; fi
        [[ $(wc -l <"$TEST_CURL_LOG") == 1 ]] || fail 'baixou artefato com metadados inválidos'
        expect_no_stages
    done
}
test_reject_oss() {
    fixture
    make_archive oss
    if juno_install_vscode; then fail 'Code OSS aceito como original'; fi
    expect_absent "$(app_path)/releases/$TEST_COMMIT"
}
test_reject_version() {
    fixture
    make_archive version
    if juno_install_vscode; then fail 'versão divergente aceita'; fi
    expect_absent "$(app_path)/releases/$TEST_COMMIT"
}
test_unsafe_archives() {
    local kind
    for kind in traversal absolute special link link-parent; do
        fixture
        make_archive "$kind"
        if juno_install_vscode; then fail "arquivo inseguro aceito: $kind"; fi
        expect_absent "$(app_path)/releases/$TEST_COMMIT"
        expect_no_stages
    done
}
test_existing_launchers_preserved() {
    fixture
    _txn_mkdir_home '.local/bin'
    _txn_mkdir_home '.local/share/applications'
    printf 'meu code anterior\n' >"$JUNO_HOME/.local/bin/code"
    printf 'meu launcher anterior\n' >"$JUNO_HOME/.local/share/applications/juno-vscode.desktop"
    juno_install_vscode
    local backup
    backup=$(find "$JUNO_STATE/apps/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    [[ $(cat "$backup/code") == 'meu code anterior' ]] || fail 'wrapper anterior perdido'
    [[ $(cat "$backup/juno-vscode.desktop") == 'meu launcher anterior' ]] || fail 'desktop anterior perdido'
}

test_existing_icon_preserved() {
    fixture
    _txn_mkdir_home '.local/share/icons/hicolor/256x256/apps'
    printf 'meu ícone anterior\n' >"$(icon_path)"
    printf 'ícone de outro aplicativo\n' >"${JUNO_HOME}/.local/share/icons/hicolor/256x256/apps/other.png"
    juno_install_vscode
    local backup
    backup=$(find "$JUNO_STATE/apps/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    [[ $(cat "$backup/visual-studio-code.png") == 'meu ícone anterior' ]] || fail 'ícone preexistente perdido'
    [[ $(cat "$JUNO_HOME/.local/share/icons/hicolor/256x256/apps/other.png") == 'ícone de outro aplicativo' ]] || fail 'arquivo vizinho do hicolor foi alterado'
    cmp -s -- "$(icon_path)" "$(app_path)/releases/$TEST_COMMIT/resources/app/resources/linux/code.png" || fail 'fallback original não foi instalado'
}

test_icon_conflict_preserves_current() {
    fixture
    juno_install_vscode
    local previous=$TEST_COMMIT
    cp -- "$JUNO_HOME/.local/bin/code" "$CASE_ROOT/previous-wrapper"
    cp -- "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" "$CASE_ROOT/previous-desktop"
    rm -- "$(icon_path)"
    mkdir -- "$(icon_path)"
    printf 'preservar\n' >"$(icon_path)/sentinel"
    TEST_COMMIT=2222222222222222222222222222222222222222
    TEST_VERSION=1.2.4
    make_archive original
    if juno_install_vscode; then fail 'diretório aceito como destino do ícone'; fi
    [[ $(current_commit) == "$previous" ]] || fail 'conflito do ícone alterou a versão atual'
    [[ $(cat "$(icon_path)/sentinel") == preservar ]] || fail 'conflito do ícone perdeu arquivos preexistentes'
    cmp -s -- "$CASE_ROOT/previous-wrapper" "$JUNO_HOME/.local/bin/code" || fail 'conflito do ícone alterou o wrapper'
    cmp -s -- "$CASE_ROOT/previous-desktop" "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" || fail 'conflito do ícone alterou o desktop'
    expect_no_stages
}

test_icon_links_rejected() {
    local kind
    for kind in symlink hardlink; do
        fixture
        _txn_mkdir_home '.local/share/icons/hicolor/256x256/apps'
        printf 'alvo preservado\n' >"$CASE_ROOT/icon-source"
        if [[ $kind == symlink ]]; then
            if ((!TEST_NATIVE_LINKS)); then
                printf 'IGNORADO: link simbólico do ícone precisa de symlinks nativos.\n'
                continue
            fi
            ln -s -- "$CASE_ROOT/icon-source" "$(icon_path)"
        else
            if ! ln -- "$CASE_ROOT/icon-source" "$(icon_path)" 2>/dev/null || [[ $(stat -c %h -- "$(icon_path)") == 1 ]]; then
                printf 'IGNORADO: hardlink do ícone indisponível; validar no Arch.\n'
                continue
            fi
        fi
        if juno_install_vscode; then fail "destino de ícone $kind aceito"; fi
        [[ $(cat "$CASE_ROOT/icon-source") == 'alvo preservado' ]] || fail 'link do ícone alterou o alvo'
        expect_absent "$JUNO_HOME/.local/bin/code"
        expect_absent "$JUNO_HOME/.local/share/applications/juno-vscode.desktop"
        if ((TEST_NATIVE_LINKS)); then expect_absent "$(app_path)/current"; else expect_absent "$(app_path)/.mock-current"; fi
        expect_no_stages
    done
}

test_icon_external_ancestor() {
    fixture
    if ((!TEST_NATIVE_LINKS)); then
        printf 'IGNORADO: ancestral externo do ícone precisa de symlinks nativos.\n'
        return
    fi
    _txn_mkdir_home '.local/share/icons'
    mkdir -- "$CASE_ROOT/outside-icons"
    printf 'preservar\n' >"$CASE_ROOT/outside-icons/sentinel"
    ln -s -- "$CASE_ROOT/outside-icons" "$JUNO_HOME/.local/share/icons/hicolor"
    if juno_install_vscode; then fail 'ícone aceitou ancestral fora do diretório pessoal'; fi
    [[ $(cat "$CASE_ROOT/outside-icons/sentinel") == preservar ]] || fail 'ancestral externo foi alterado'
    [[ $(find "$CASE_ROOT/outside-icons" -mindepth 1 | wc -l) == 1 ]] || fail 'arquivos criados fora do diretório pessoal'
    expect_absent "$JUNO_HOME/.local/bin/code"
    expect_no_stages
}
test_wrapper_quotes() {
    fixture
    juno_install_vscode
    # Wrapper is usable without a genuine current symlink in the Windows test.
    if ((!TEST_NATIVE_LINKS)); then
        mkdir -- "$(app_path)/current"
        cp -r -- "$(app_path)/releases/$TEST_COMMIT/bin" "$(app_path)/current/bin"
    fi
    # shellcheck disable=SC2016
    "$JUNO_HOME/.local/bin/code" 'a b' "O'Neil" '$(touch /never)' '%F'
    local -a arguments=()
    mapfile -d '' -t arguments <"$TEST_CODE_ARGS"
    # shellcheck disable=SC2016
    [[ ${#arguments[@]} == 4 && ${arguments[0]} == 'a b' && ${arguments[1]} == "O'Neil" && ${arguments[2]} == '$(touch /never)' && ${arguments[3]} == '%F' ]] || fail 'wrapper não preservou os argumentos'
    local exec_line
    exec_line=$(sed -n 's/^Exec=//p' "$JUNO_HOME/.local/share/applications/juno-vscode.desktop")
    [[ $exec_line == *'%%'* && $exec_line == *'\\$'* && $exec_line == *'" %F' ]] || fail 'escapes do launcher inválidos'
}
test_existing_manifest_corrupt() {
    fixture
    juno_install_vscode
    printf '{}\n' >"$(app_path)/releases/$TEST_COMMIT/.juno-vscode.json"
    if juno_install_vscode; then fail 'manifesto alterado não foi detectado'; fi
    [[ $(wc -l <"$TEST_CURL_LOG") == 3 ]] || fail 'manifesto inválido provocou novo download'
}
test_lock_required() {
    fixture
    JUNO_LOCK_HELD=0
    if juno_install_vscode; then fail 'download sem bloqueio permitido'; fi
    [[ ! -s $TEST_CURL_LOG ]] || fail 'consulta sem bloqueio foi executada'
}
test_external_ancestor() {
    fixture
    if ((!TEST_NATIVE_LINKS)); then
        printf 'IGNORADO: ancestral externo precisa de symlinks nativos.\n'
        return
    fi
    _txn_mkdir_home '.local/share/juno-apps'
    mkdir -- "$CASE_ROOT/outside"
    ln -s -- "$CASE_ROOT/outside" "$JUNO_HOME/.local/share/juno-apps/vscode"
    if juno_install_vscode; then fail 'link externo aceito'; fi
    [[ ! -s $TEST_CURL_LOG ]] || fail 'consulta realizada com ancestral externo'
}

test_debian_install() {
    debian_fixture
    _txn_mkdir_home '.local/share/juno-apps/vscode/releases'
    printf 'preservar release do usuário\n' > "$(app_path)/releases/sentinel"
    _txn_mkdir_home '.config/Code/User'
    printf '{"custom":true}\n' > "$JUNO_HOME/.config/Code/User/settings.json"
    juno_install_vscode
    grep -qx 'code code/add-microsoft-repo boolean false' "$TEST_APT_LOG" || fail 'opt-out do repositório Microsoft ausente'
    grep -q '^install --no-install-recommends --no-remove -- ' "$TEST_APT_LOG" || fail 'instalação Debian sem restrição de remoções'
    "$JUNO_HOME/.local/bin/code" native-argument
    [[ $(tr -d '\000' < "$TEST_CODE_ARGS") == native-argument ]] || fail 'wrapper não usa executável nativo'
    [[ $(cat "$(app_path)/releases/sentinel") == 'preservar release do usuário' ]] || fail 'release antiga do usuário alterada'
    [[ $(cat "$JUNO_HOME/.config/Code/User/settings.json") == '{"custom":true}' ]] || fail 'preferências anteriores alteradas'
    expect_absent "$JUNO_HOME/.local/share/applications/juno-vscode.desktop"
    cmp -s -- "$(icon_path)" "$TEST_NATIVE_ROOT/resources/app/resources/linux/code.png" || fail 'fallback nativo ausente'
    jq -e '.installMethod == "deb" and .installedVersion == "1.2.3"' "$JUNO_STATE/apps/vscode.json" >/dev/null
    [[ $(wc -l < "$TEST_CURL_LOG") == 2 ]] || fail 'download Debian incompleto'
}

test_debian_idempotence() {
    debian_fixture
    juno_install_vscode
    juno_install_vscode
    [[ $(wc -l < "$TEST_CURL_LOG") == 3 ]] || fail 'pacote Debian existente foi baixado novamente'
    [[ $(grep -c '^install ' "$TEST_APT_LOG") == 1 ]] || fail 'APT repetido para versão instalada'
    [[ ! -d $JUNO_STATE/apps/backups ]] || fail 'launcher Debian idêntico criou backup'
}

test_debian_legacy_launcher_preserved() {
    debian_fixture
    _txn_mkdir_home '.local/share/applications'
    printf '[Desktop Entry]\nName=Visual Studio Code\nX-Juno-Managed=true\n' > "$JUNO_HOME/.local/share/applications/juno-vscode.desktop"
    cp -- "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" "$CASE_ROOT/previous-desktop"
    juno_install_vscode
    grep -qx 'Hidden=true' "$JUNO_HOME/.local/share/applications/juno-vscode.desktop" || fail 'launcher antigo produziria entrada duplicada'
    local backup
    backup=$(find "$JUNO_STATE/apps/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)
    cmp -s -- "$backup/juno-vscode.desktop" "$CASE_ROOT/previous-desktop" || fail 'launcher antigo não foi preservado'
    juno_install_vscode
    [[ $(find "$JUNO_STATE/apps/backups" -mindepth 1 -maxdepth 1 -type d | wc -l) == 1 ]] || fail 'tombstone idêntico criou outro backup'
}

test_debian_newer_preserved() {
    debian_fixture
    juno_install_vscode
    printf 'installed\tamd64\t1.2.4-1234567890\n' > "$TEST_DPKG_STATE"
    jq '.version="1.2.4"' "$TEST_NATIVE_ROOT/resources/app/package.json" > "$CASE_ROOT/changed.json"
    mv -- "$CASE_ROOT/changed.json" "$TEST_NATIVE_ROOT/resources/app/package.json"
    juno_install_vscode
    [[ $(wc -l < "$TEST_CURL_LOG") == 3 ]] || fail 'versão Debian mais nova provocou download'
    [[ $(grep -c '^install ' "$TEST_APT_LOG") == 1 ]] || fail 'versão Debian mais nova foi substituída'
    jq -e '.installedVersion == "1.2.4"' "$JUNO_STATE/apps/vscode.json" >/dev/null
}

test_debian_invalid_identity() {
    local kind
    for kind in package architecture version; do
        debian_fixture
        case $kind in
            package) make_debian code-oss amd64 "$TEST_VERSION-1234567890" ;;
            architecture) make_debian code arm64 "$TEST_VERSION-1234567890" ;;
            version) make_debian code amd64 1.2.2-1234567890 ;;
        esac
        if juno_install_vscode; then fail "pacote Debian inválido aceito: $kind"; fi
        [[ ! -s $TEST_APT_LOG ]] || fail 'pacote inválido chegou ao sudo/APT'
        expect_absent "$JUNO_HOME/.local/bin/code"
    done
}

test_debian_corrupt_preserves_launchers() {
    debian_fixture
    _txn_mkdir_home '.local/bin'
    printf 'launcher anterior\n' > "$JUNO_HOME/.local/bin/code"
    printf 'corrompido\n' >> "$TEST_ARCHIVE"
    if juno_install_vscode; then fail 'checksum Debian inválido aceito'; fi
    [[ ! -s $TEST_APT_LOG ]] || fail 'pacote corrompido chegou ao APT'
    [[ $(cat "$JUNO_HOME/.local/bin/code") == 'launcher anterior' ]] || fail 'download corrompido alterou launcher'
}

test_debian_apt_failure() {
    debian_fixture
    TEST_APT_FAIL=1
    _txn_mkdir_home '.local/bin'
    printf 'launcher anterior\n' > "$JUNO_HOME/.local/bin/code"
    if juno_install_vscode; then fail 'falha APT ignorada'; fi
    [[ $(cat "$JUNO_HOME/.local/bin/code") == 'launcher anterior' ]] || fail 'falha APT alterou launcher'
    expect_absent "$JUNO_STATE/apps/vscode.json"
}

test_debian_unmanaged_native_conflict() {
    debian_fixture
    mkdir -- "$TEST_NATIVE_ROOT"
    printf 'preservar\n' > "$TEST_NATIVE_ROOT/sentinel"
    if juno_install_vscode; then fail 'diretório nativo sem pacote Debian foi sobrescrito'; fi
    [[ $(cat "$TEST_NATIVE_ROOT/sentinel") == preservar ]] || fail 'diretório nativo divergente alterado'
    [[ ! -s $TEST_APT_LOG && $(wc -l < "$TEST_CURL_LOG") == 1 ]] || fail 'conflito nativo executou instalação'
}

test_debian_existing_oss_conflict() {
    debian_fixture
    juno_install_vscode
    jq '.nameLong="Code - OSS"' "$TEST_NATIVE_ROOT/resources/app/product.json" > "$CASE_ROOT/changed.json"
    mv -- "$CASE_ROOT/changed.json" "$TEST_NATIVE_ROOT/resources/app/product.json"
    if juno_install_vscode; then fail 'Code OSS nativo foi aceito como Microsoft'; fi
    [[ $(grep -c '^install ' "$TEST_APT_LOG") == 1 ]] || fail 'conflito Code OSS executou APT'
}

test_debian_global_launcher_preserved() {
    local kind
    for kind in file symlink; do
        debian_fixture
        if [[ $kind == symlink ]]; then
            if ((!TEST_NATIVE_LINKS)); then
                printf 'IGNORADO: launcher global por symlink exige links nativos.\n'
                continue
            fi
            printf 'alvo global preservado\n' > "$CASE_ROOT/global-source"
            ln -s -- "$CASE_ROOT/global-source" "$TEST_GLOBAL_LAUNCHER"
        else
            printf 'launcher global preservado\n' > "$TEST_GLOBAL_LAUNCHER"
        fi
        if juno_install_vscode; then fail "launcher global $kind existente foi aceito pelo APT"; fi
        [[ -s $TEST_GLOBAL_LAUNCHER ]] || fail 'launcher global perdido'
        [[ ! -s $TEST_APT_LOG && $(wc -l < "$TEST_CURL_LOG") == 1 ]] || fail 'conflito global provocou download/APT'
        expect_absent "$JUNO_HOME/.local/bin/code"
    done
}

count=0
for test in test_install test_idempotence test_update_retains_previous test_corrupt_preserves_current \
    test_failed_binary test_offline test_untrusted_metadata test_reject_oss test_reject_version \
    test_unsafe_archives test_existing_launchers_preserved test_existing_icon_preserved \
    test_icon_conflict_preserves_current test_icon_links_rejected test_icon_external_ancestor \
    test_wrapper_quotes test_existing_manifest_corrupt \
    test_lock_required test_external_ancestor test_debian_install test_debian_idempotence test_debian_legacy_launcher_preserved \
    test_debian_newer_preserved test_debian_invalid_identity test_debian_corrupt_preserves_launchers \
    test_debian_apt_failure test_debian_unmanaged_native_conflict test_debian_existing_oss_conflict \
    test_debian_global_launcher_preserved; do
    ("$test")
    count=$((count + 1))
    printf 'OK: %s\n' "$test"
done
printf '%s cenários do VS Code concluídos.\n' "$count"
