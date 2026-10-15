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
    https://update.code.visualstudio.com/api/update/linux-x64/stable/latest)
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
    export TEST_ARCHIVE TEST_METADATA TEST_CURL_LOG TEST_OFFLINE TEST_BINARY_FAIL TEST_CODE_ARGS
    # The real helper's allowlist is extended to apps in the main installer.
    _txn_mkdir_home '.local/state/juno-desktop/apps'
    make_archive original
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
    "resources/app/resources/linux/code.png": b"image fixture",
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
test_wrapper_quotes() {
    fixture
    juno_install_vscode
    # Wrapper is usable without a genuine current symlink in the Windows test.
    if ((!TEST_NATIVE_LINKS)); then
        mkdir -- "$(app_path)/current"
        cp -r -- "$(app_path)/releases/$TEST_COMMIT/bin" "$(app_path)/current/bin"
    fi
    "$JUNO_HOME/.local/bin/code" 'a b' "O'Neil" '$(touch /never)' '%F'
    local -a arguments=()
    mapfile -d '' -t arguments <"$TEST_CODE_ARGS"
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

count=0
for test in test_install test_idempotence test_update_retains_previous test_corrupt_preserves_current \
    test_failed_binary test_offline test_untrusted_metadata test_reject_oss test_reject_version \
    test_unsafe_archives test_existing_launchers_preserved test_wrapper_quotes test_existing_manifest_corrupt \
    test_lock_required test_external_ancestor; do
    ("$test")
    count=$((count + 1))
    printf 'OK: %s\n' "$test"
done
printf '%s cenários do VS Code concluídos.\n' "$count"
